package com.aliveecho.codecompanion

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.aliveecho.codecompanion.data.ModelDownloader
import com.aliveecho.codecompanion.inference.InferenceEngine
import kotlinx.coroutines.Dispatchers
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

data class AppUiState(
    val code: String = DEFAULT_CODE,
    val chatInput: String = "",
    val messages: List<ChatMessage> = listOf(
        ChatMessage(
            role = "assistant",
            content = "Ciao! Carica un modello nella scheda Modelli, poi chiedimi aiuto sul codice.",
        ),
    ),
    val selectedModelId: String? = null,
    val loadedModelLabel: String? = null,
    val engineStatus: String = "Avvio motore…",
    val engineReady: Boolean = false,
    val busy: Boolean = false,
    val downloadProgress: Map<String, Float> = emptyMap(),
    val downloadedIds: Set<String> = emptySet(),
    val error: String? = null,
)

private const val DEFAULT_CODE = """fun greet(name: String): String {
    return "Ciao, " + name + "!"
}

fun main() {
    println(greet("mondo"))
}
"""

class AppViewModel(application: Application) : AndroidViewModel(application) {
    val engine = InferenceEngine(application)
    private val downloader = ModelDownloader(application.filesDir.resolve("models"))

    private val _ui = MutableStateFlow(AppUiState())
    val ui: StateFlow<AppUiState> = _ui.asStateFlow()

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
    }

    fun updateChatInput(value: String) {
        _ui.update { it.copy(chatInput = value) }
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

    fun sendChat() {
        val state = _ui.value
        val userText = state.chatInput.trim()
        if (userText.isEmpty() || state.busy) return
        if (state.loadedModelLabel == null) {
            _ui.update { it.copy(error = "Carica prima un modello dalla scheda Modelli.") }
            return
        }

        val prompt = buildPrompt(state.code, userText)
        _ui.update {
            it.copy(
                busy = true,
                chatInput = "",
                error = null,
                messages = it.messages + ChatMessage("user", userText) + ChatMessage("assistant", "…"),
            )
        }

        viewModelScope.launch {
            try {
                val answer = engine.complete(prompt, maxTokens = 320)
                _ui.update { uiState ->
                    val msgs = uiState.messages.toMutableList()
                    if (msgs.isNotEmpty() && msgs.last().role == "assistant") {
                        msgs[msgs.lastIndex] = ChatMessage("assistant", answer.ifBlank { "(nessuna risposta)" })
                    }
                    uiState.copy(messages = msgs, busy = false)
                }
            } catch (e: Exception) {
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

    private fun refreshDownloaded() {
        val downloaded = ModelCatalog.models
            .filter { downloader.isDownloaded(it.repo, it.file) }
            .map { it.id }
            .toSet()
        _ui.update { it.copy(downloadedIds = downloaded) }
    }

    private fun buildPrompt(code: String, userText: String): String {
        return """
            Sei un assistente di programmazione locale. Rispondi in italiano, in modo chiaro e concreto.
            Aiuta a scrivere, spiegare e correggere codice.

            CODICE APERTO NELL'EDITOR:
            ```
            $code
            ```

            RICHIESTA UTENTE:
            $userText

            RISPOSTA:
        """.trimIndent()
    }
}
