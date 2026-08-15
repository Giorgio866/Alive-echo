package com.aliveecho.codecompanion

import android.app.Application
import android.content.Context
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.aliveecho.codecompanion.data.CompileClient
import com.aliveecho.codecompanion.data.CompileResult
import com.aliveecho.codecompanion.data.ModelDownloader
import com.aliveecho.codecompanion.inference.InferenceEngine
import com.aliveecho.codecompanion.runtime.LocalRuntimeEngine
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

data class ChatMessage(
    val role: String,
    val content: String,
)

enum class CompileMode {
    LOCAL,
    REMOTE,
}

data class AppUiState(
    val code: String = DEFAULT_CODE,
    val language: String = "python",
    val chatInput: String = "",
    val messages: List<ChatMessage> = listOf(
        ChatMessage(
            role = "assistant",
            content = "Ciao! La compilazione gira DENTRO l'app (Python e JavaScript). Carica un modello, scrivi codice: parte in automatico.",
        ),
    ),
    val selectedModelId: String? = null,
    val loadedModelLabel: String? = null,
    val engineStatus: String = "Avvio motore…",
    val engineReady: Boolean = false,
    val localRuntimeReady: Boolean = false,
    val busy: Boolean = false,
    val downloadProgress: Map<String, Float> = emptyMap(),
    val downloadedIds: Set<String> = emptySet(),
    val error: String? = null,
    val compileMode: CompileMode = CompileMode.LOCAL,
    val compileServerUrl: String = "http://192.168.1.1:8765",
    val autoCompile: Boolean = true,
    val autoFixOnError: Boolean = true,
    val serverOnline: Boolean? = null,
    val serverTools: String = "",
    val compiling: Boolean = false,
    val lastCompile: CompileResult? = null,
    val compileLog: String = "Nessuna compilazione ancora.",
)

private const val DEFAULT_CODE = """def greet(name):
    return "Ciao, " + name + "!"

print(greet("mondo"))
"""

private const val PREFS = "codecompanion"
private const val KEY_SERVER = "compile_server_url"
private const val KEY_AUTO = "auto_compile"
private const val KEY_AUTO_FIX = "auto_fix"
private const val KEY_LANG = "language"
private const val KEY_MODE = "compile_mode"

class AppViewModel(application: Application) : AndroidViewModel(application) {
    val engine = InferenceEngine(application)
    val localRuntime = LocalRuntimeEngine()
    private val downloader = ModelDownloader(application.filesDir.resolve("models"))
    private val compileClient = CompileClient()
    private val prefs = application.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private val _ui = MutableStateFlow(
        AppUiState(
            compileServerUrl = prefs.getString(KEY_SERVER, "http://192.168.1.1:8765")
                ?: "http://192.168.1.1:8765",
            autoCompile = prefs.getBoolean(KEY_AUTO, true),
            autoFixOnError = prefs.getBoolean(KEY_AUTO_FIX, true),
            language = prefs.getString(KEY_LANG, "python") ?: "python",
            compileMode = if (prefs.getString(KEY_MODE, "local") == "remote") {
                CompileMode.REMOTE
            } else {
                CompileMode.LOCAL
            },
        ),
    )
    val ui: StateFlow<AppUiState> = _ui.asStateFlow()

    private var compileJob: Job? = null
    private var autoFixInFlight = false

    init {
        refreshDownloaded()
        viewModelScope.launch {
            engine.status.collect { status ->
                _ui.update { it.copy(engineStatus = status) }
            }
        }
        viewModelScope.launch {
            engine.engineReady.collect { ready ->
                _ui.update { it.copy(engineReady = ready) }
            }
        }
        viewModelScope.launch {
            engine.loadedModel.collect { model ->
                _ui.update { it.copy(loadedModelLabel = model) }
            }
        }
        viewModelScope.launch {
            localRuntime.ready.collect { ready ->
                _ui.update { it.copy(localRuntimeReady = ready) }
                if (ready && _ui.value.autoCompile) {
                    scheduleCompile(immediate = true)
                }
            }
        }
        viewModelScope.launch {
            engine.tokenStream.collect { partial ->
                _ui.update { state ->
                    val msgs = state.messages.toMutableList()
                    if (msgs.isNotEmpty() && msgs.last().role == "assistant" && state.busy) {
                        msgs[msgs.lastIndex] = ChatMessage("assistant", partial)
                        state.copy(messages = msgs)
                    } else {
                        state
                    }
                }
            }
        }
    }

    fun updateCode(code: String) {
        _ui.update { it.copy(code = code) }
        if (_ui.value.autoCompile) {
            scheduleCompile(immediate = false)
        }
    }

    fun updateLanguage(language: String) {
        prefs.edit().putString(KEY_LANG, language).apply()
        _ui.update { it.copy(language = language) }
        if (_ui.value.autoCompile) {
            scheduleCompile(immediate = true)
        }
    }

    fun updateChatInput(value: String) {
        _ui.update { it.copy(chatInput = value) }
    }

    fun updateServerUrl(url: String) {
        prefs.edit().putString(KEY_SERVER, url).apply()
        _ui.update { it.copy(compileServerUrl = url) }
    }

    fun setCompileMode(mode: CompileMode) {
        prefs.edit().putString(KEY_MODE, if (mode == CompileMode.LOCAL) "local" else "remote").apply()
        _ui.update { it.copy(compileMode = mode) }
        if (_ui.value.autoCompile) {
            scheduleCompile(immediate = true)
        }
    }

    fun setAutoCompile(enabled: Boolean) {
        prefs.edit().putBoolean(KEY_AUTO, enabled).apply()
        _ui.update { it.copy(autoCompile = enabled) }
        if (enabled) scheduleCompile(immediate = true)
    }

    fun setAutoFixOnError(enabled: Boolean) {
        prefs.edit().putBoolean(KEY_AUTO_FIX, enabled).apply()
        _ui.update { it.copy(autoFixOnError = enabled) }
    }

    fun clearError() {
        _ui.update { it.copy(error = null) }
    }

    fun sendCodeToChat() {
        val snippet = _ui.value.code.trim()
        if (snippet.isEmpty()) return
        _ui.update {
            it.copy(
                chatInput = "Aiutami a migliorare questo codice:\n\n```\n$snippet\n```",
            )
        }
    }

    fun checkServer() {
        viewModelScope.launch {
            val url = _ui.value.compileServerUrl
            val (ok, detail) = withContext(Dispatchers.IO) {
                compileClient.health(url)
            }
            _ui.update {
                it.copy(
                    serverOnline = ok,
                    serverTools = detail,
                    compileLog = if (ok) {
                        "Server PC online. Tool: $detail"
                    } else {
                        "Server PC offline: $detail"
                    },
                )
            }
        }
    }

    fun compileNow() {
        scheduleCompile(immediate = true)
    }

    fun downloadModel(model: HfModel) {
        viewModelScope.launch {
            _ui.update { it.copy(busy = true, error = null) }
            try {
                withContext(Dispatchers.IO) {
                    downloader.download(model.repo, model.file) { p ->
                        val fraction = if (p.totalBytes > 0) {
                            p.bytesRead.toFloat() / p.totalBytes.toFloat()
                        } else {
                            0f
                        }
                        _ui.update { state ->
                            state.copy(
                                downloadProgress = state.downloadProgress + (model.id to fraction),
                            )
                        }
                    }
                }
                refreshDownloaded()
            } catch (e: Exception) {
                _ui.update { it.copy(error = e.message ?: "Download fallito") }
            } finally {
                _ui.update { it.copy(busy = false) }
            }
        }
    }

    fun loadModel(model: HfModel) {
        viewModelScope.launch {
            _ui.update { it.copy(busy = true, error = null, selectedModelId = model.id) }
            try {
                engine.loadModel(model.repo, model.file)
                _ui.update {
                    it.copy(
                        loadedModelLabel = "${model.name} (${model.repo}/${model.file})",
                    )
                }
            } catch (e: Exception) {
                _ui.update { it.copy(error = e.message ?: "Caricamento modello fallito") }
            } finally {
                _ui.update { it.copy(busy = false) }
            }
        }
    }

    fun sendChat(userOverride: String? = null, fromAutoFix: Boolean = false) {
        val state = _ui.value
        val userText = (userOverride ?: state.chatInput).trim()
        if (userText.isEmpty() || state.busy) return
        if (state.loadedModelLabel == null) {
            _ui.update { it.copy(error = "Carica prima un modello dalla scheda Modelli.") }
            return
        }

        val prompt = buildPrompt(state.code, userText, state.lastCompile)
        _ui.update {
            it.copy(
                busy = true,
                chatInput = if (userOverride == null) "" else it.chatInput,
                error = null,
                messages = it.messages + ChatMessage("user", userText) + ChatMessage("assistant", "…"),
            )
        }

        viewModelScope.launch {
            try {
                val answer = engine.complete(prompt, maxTokens = 420)
                val extracted = CodeExtractor.extractBestCode(answer)
                _ui.update { uiState ->
                    val msgs = uiState.messages.toMutableList()
                    if (msgs.isNotEmpty() && msgs.last().role == "assistant") {
                        msgs[msgs.lastIndex] = ChatMessage(
                            "assistant",
                            answer.ifBlank { "(nessuna risposta)" },
                        )
                    }
                    val newCode = extracted?.first
                    val newLang = extracted?.second
                    uiState.copy(
                        messages = msgs,
                        busy = false,
                        code = newCode ?: uiState.code,
                        language = newLang ?: uiState.language,
                    )
                }
                if (extracted != null) {
                    prefs.edit().putString(KEY_LANG, _ui.value.language).apply()
                    scheduleCompile(immediate = true, allowAutoFix = !fromAutoFix)
                }
                if (fromAutoFix) autoFixInFlight = false
            } catch (e: Exception) {
                if (fromAutoFix) autoFixInFlight = false
                _ui.update {
                    it.copy(
                        busy = false,
                        error = e.message ?: "Generazione fallita",
                        messages = it.messages.dropLast(1) + ChatMessage(
                            "assistant",
                            "Errore: ${e.message}",
                        ),
                    )
                }
            }
        }
    }

    private fun scheduleCompile(immediate: Boolean, allowAutoFix: Boolean = true) {
        compileJob?.cancel()
        compileJob = viewModelScope.launch {
            if (!immediate) delay(700)
            runCompile(allowAutoFix = allowAutoFix)
        }
    }

    private suspend fun runCompile(allowAutoFix: Boolean) {
        val state = _ui.value
        if (state.code.isBlank()) return
        _ui.update { it.copy(compiling = true) }

        val result = when (state.compileMode) {
            CompileMode.LOCAL -> {
                if (state.language !in listOf("python", "javascript")) {
                    CompileResult(
                        ok = false,
                        exitCode = 1,
                        stdout = "",
                        stderr = "In modalità App sono supportati Python e JavaScript. Cambia linguaggio oppure attiva modalità PC per Java/Kotlin.",
                        durationMs = 0,
                        language = state.language,
                        phase = "local",
                    )
                } else {
                    localRuntime.run(state.language, state.code)
                }
            }
            CompileMode.REMOTE -> withContext(Dispatchers.IO) {
                compileClient.compile(state.compileServerUrl, state.language, state.code)
            }
        }

        val where = if (state.compileMode == CompileMode.LOCAL) "APP" else "PC"
        val log = buildString {
            append(if (result.ok) "OK" else "ERRORE")
            append(" · $where")
            append(" · exit ${result.exitCode}")
            append(" · ${result.durationMs} ms")
            append(" · ${result.language ?: state.language}")
            append('\n')
            append(result.combinedOutput.ifBlank { "(nessun output)" })
        }
        _ui.update {
            it.copy(
                compiling = false,
                lastCompile = result,
                compileLog = log,
                serverOnline = if (result.phase == "network") false else it.serverOnline,
            )
        }

        if (
            allowAutoFix &&
            !result.ok &&
            state.autoFixOnError &&
            state.loadedModelLabel != null &&
            !autoFixInFlight &&
            result.phase != "network"
        ) {
            autoFixInFlight = true
            val fixPrompt = buildString {
                appendLine("Il codice non compila/esegue nell'app. Correggilo.")
                appendLine("Linguaggio: ${state.language}")
                appendLine("Errori:")
                appendLine(result.combinedOutput)
                appendLine("Restituisci SOLO il codice corretto in un blocco markdown.")
            }
            sendChat(userOverride = fixPrompt, fromAutoFix = true)
        } else if (result.ok) {
            autoFixInFlight = false
        }
    }

    private fun refreshDownloaded() {
        val downloaded = ModelCatalog.models
            .filter { downloader.isDownloaded(it.repo, it.file) }
            .map { it.id }
            .toSet()
        _ui.update { it.copy(downloadedIds = downloaded) }
    }

    private fun buildPrompt(code: String, userText: String, lastCompile: CompileResult?): String {
        val compileInfo = if (lastCompile == null) {
            "Nessuna compilazione recente."
        } else {
            "Ultima compilazione: ok=${lastCompile.ok}\n${lastCompile.combinedOutput}"
        }
        return """
            Sei un assistente di programmazione. Rispondi in italiano.
            Quando proponi una modifica, includi SEMPRE il file completo in un blocco ```linguaggio.
            Preferisci Python o JavaScript perché possono essere eseguiti DENTRO l'app Android.

            CODICE APERTO:
            ```
            $code
            ```

            STATO COMPILAZIONE:
            $compileInfo

            RICHIESTA:
            $userText

            RISPOSTA:
        """.trimIndent()
    }
}
