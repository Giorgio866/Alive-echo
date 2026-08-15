package com.aliveecho.codecompanion

import android.app.Application
import android.content.Context
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import android.graphics.BitmapFactory
import android.util.Base64
import com.aliveecho.codecompanion.data.CompileClient
import com.aliveecho.codecompanion.data.CompileResult
import com.aliveecho.codecompanion.data.HfSearchHit
import com.aliveecho.codecompanion.data.HuggingFaceApi
import com.aliveecho.codecompanion.data.ModelDownloader
import com.aliveecho.codecompanion.image.ImageEngine
import com.aliveecho.codecompanion.image.PhoneImageClient
import com.aliveecho.codecompanion.inference.InferenceEngine
import com.aliveecho.codecompanion.runtime.LocalRuntimeEngine
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import com.aliveecho.codecompanion.web.AssetWebView
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.TimeoutCancellationException
import kotlinx.coroutines.delay
import kotlinx.coroutines.withTimeout
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
    val downloadedModels: List<HfModel> = emptyList(),
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
    val hfQuery: String = "uncensored gguf",
    val hfToken: String = "",
    val hfSearching: Boolean = false,
    val hfResults: List<HfSearchHit> = emptyList(),
    val hfFiles: List<String> = emptyList(),
    val selectedHfRepo: String? = null,
    val customModels: List<HfModel> = emptyList(),
    val imagePrompt: String = "",
    val imageStatus: String = "Motore veloce pronto. Scrivi un prompt e premi Genera.",
    val imageEngineReady: Boolean = false,
    val loadedImageModel: String? = null,
    val generatingImage: Boolean = false,
    val lastImagePath: String? = null,
    val localQuery: String = "",
    val imageProgress: Float = 0f,
    val imageDownloading: Boolean = false,
    val imageDownloadLabel: String = "",
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
private const val KEY_TOKEN = "hf_token"
private const val KEY_CUSTOM = "custom_models"

class AppViewModel(application: Application) : AndroidViewModel(application) {
    val engine = InferenceEngine(application)
    val localRuntime = LocalRuntimeEngine()
    val imageEngine = ImageEngine()
    private val phoneImages = PhoneImageClient(application.filesDir.resolve("images"))
    private val downloader = ModelDownloader(application.filesDir.resolve("models"))
    private val compileClient = CompileClient()
    private val hfApi = HuggingFaceApi()
    private val prefs = application.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    private val imagesDir = application.filesDir.resolve("images").apply { mkdirs() }

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
            hfToken = prefs.getString(KEY_TOKEN, "") ?: "",
            customModels = loadCustomModels(),
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
            imageEngine.ready.collect { ready ->
                _ui.update { it.copy(imageEngineReady = ready) }
            }
        }
        viewModelScope.launch {
            imageEngine.status.collect { status ->
                _ui.update { it.copy(imageStatus = status) }
            }
        }
        viewModelScope.launch {
            imageEngine.loadedModel.collect { model ->
                _ui.update { it.copy(loadedImageModel = model) }
            }
        }
        viewModelScope.launch {
            imageEngine.progress.collect { p ->
                _ui.update { state ->
                    if (!state.imageDownloading && p < 0.02f) return@update state
                    val id = state.selectedModelId
                    val merged = maxOf(state.imageProgress, p)
                    state.copy(
                        imageProgress = merged,
                        downloadProgress = if (id != null && state.imageDownloading) {
                            state.downloadProgress + (id to merged)
                        } else {
                            state.downloadProgress
                        },
                    )
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
        rememberCustom(model)
        if (model.kind == ModelKind.IMAGE) {
            loadImageModel(model)
            return
        }
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
        rememberCustom(model)
        if (model.kind == ModelKind.IMAGE) {
            loadImageModel(model)
            return
        }
        viewModelScope.launch {
            _ui.update { it.copy(busy = true, error = null, selectedModelId = model.id) }
            try {
                if (!downloader.isDownloaded(model.repo, model.file)) {
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
                }
                val local = downloader.localFile(model.repo, model.file)
                val localUrl = if (local.exists() && local.length() > 0L) {
                    AssetWebView.modelUrl(local.name)
                } else {
                    null
                }
                withTimeout(8 * 60 * 1000L) {
                    engine.loadModel(model.repo, model.file, localUrl)
                }
                _ui.update {
                    it.copy(
                        loadedModelLabel = "${model.name} (${model.repo}/${model.file})",
                    )
                }
            } catch (e: TimeoutCancellationException) {
                _ui.update { it.copy(error = "Caricamento troppo lento. Riprova con un modello più piccolo (1B–3B).") }
            } catch (e: Exception) {
                _ui.update { it.copy(error = e.message ?: "Caricamento modello fallito") }
            } finally {
                _ui.update { it.copy(busy = false) }
            }
        }
    }

    fun updateLocalQuery(value: String) {
        _ui.update { it.copy(localQuery = value) }
    }

    fun updateHfQuery(value: String) {
        _ui.update { it.copy(hfQuery = value) }
    }

    fun importFromUri(uri: android.net.Uri) {
        viewModelScope.launch {
            _ui.update { it.copy(busy = true, error = null) }
            try {
                val app = getApplication<Application>()
                val name = displayName(uri)
                val lower = name.lowercase()
                if (!lower.endsWith(".gguf") && !lower.endsWith(".bin")) {
                    throw IllegalStateException("Scegli un file .gguf (modello AI).")
                }
                withContext(Dispatchers.IO) {
                    val resolver = app.contentResolver
                    val total = resolver.openAssetFileDescriptor(uri, "r")?.use { it.length } ?: -1L
                    resolver.openInputStream(uri)?.use { input ->
                        downloader.importStream(name, input, total) { p ->
                            val fraction = if (p.totalBytes > 0) {
                                p.bytesRead.toFloat() / p.totalBytes.toFloat()
                            } else {
                                0f
                            }
                            _ui.update { state ->
                                state.copy(downloadProgress = state.downloadProgress + ("import" to fraction))
                            }
                        }
                    } ?: throw IllegalStateException("Impossibile aprire il file")
                }
                refreshDownloaded()
            } catch (e: Exception) {
                _ui.update { it.copy(error = e.message ?: "Importazione fallita") }
            } finally {
                _ui.update { it.copy(busy = false) }
            }
        }
    }

    private fun displayName(uri: android.net.Uri): String {
        val resolver = getApplication<Application>().contentResolver
        resolver.query(uri, arrayOf(android.provider.OpenableColumns.DISPLAY_NAME), null, null, null)
            ?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val idx = cursor.getColumnIndex(android.provider.OpenableColumns.DISPLAY_NAME)
                    if (idx >= 0) {
                        val value = cursor.getString(idx)
                        if (!value.isNullOrBlank()) return value
                    }
                }
            }
        return uri.lastPathSegment?.substringAfterLast('/') ?: "model.gguf"
    }

    fun updateHfToken(value: String) {
        prefs.edit().putString(KEY_TOKEN, value).apply()
        _ui.update { it.copy(hfToken = value) }
    }

    fun updateImagePrompt(value: String) {
        _ui.update { it.copy(imagePrompt = value) }
    }

    fun searchHuggingFace() {
        val query = _ui.value.hfQuery.trim()
        viewModelScope.launch {
            _ui.update { it.copy(hfSearching = true, error = null) }
            try {
                val results = withContext(Dispatchers.IO) {
                    hfApi.search(query, _ui.value.hfToken.ifBlank { null })
                }
                _ui.update { it.copy(hfResults = results, hfSearching = false, hfFiles = emptyList()) }
            } catch (e: Exception) {
                _ui.update {
                    it.copy(
                        hfSearching = false,
                        error = e.message ?: "Ricerca Hugging Face fallita",
                    )
                }
            }
        }
    }

    fun pickHfRepo(hit: HfSearchHit) {
        viewModelScope.launch {
            _ui.update { it.copy(hfSearching = true, error = null, selectedHfRepo = hit.repoId) }
            try {
                val files = withContext(Dispatchers.IO) {
                    hfApi.listFiles(hit.repoId, _ui.value.hfToken.ifBlank { null })
                }
                val gguf = files.filter { it.endsWith(".gguf", ignoreCase = true) }
                val model = hfApi.toModelFromRepo(hit.repoId, null, hit.pipelineTag, files)
                rememberCustom(model)
                _ui.update {
                    it.copy(
                        hfFiles = gguf,
                        selectedHfRepo = hit.repoId,
                        hfSearching = false,
                    )
                }
            } catch (e: Exception) {
                _ui.update {
                    it.copy(
                        hfSearching = false,
                        error = e.message ?: "Impossibile leggere il repo",
                    )
                }
            }
        }
    }

    fun addCustomGguf(repo: String, file: String) {
        val model = HfModel(
            id = "custom-" + repo.replace('/', '_') + "-" + file.hashCode(),
            name = repo.substringAfterLast('/') + " / " + file.substringAfterLast('/'),
            repo = repo.trim(),
            file = file.trim(),
            sizeLabel = "GGUF",
            description = "Modello scelto da Hugging Face",
            tags = listOf("custom"),
            kind = ModelKind.LLM,
        )
        rememberCustom(model)
        downloadModel(model)
    }

    private var imageLoadJob: Job? = null

    fun loadImageModel(model: HfModel) {
        rememberCustom(model)
        if (imageLoadJob?.isActive == true) return
        if (isPhoneFastImage(model) || isHeavyImageModel(model)) {
            _ui.update {
                it.copy(
                    selectedModelId = model.id,
                    loadedImageModel = "veloce",
                    imageDownloading = false,
                    imageProgress = 1f,
                    imageDownloadLabel = "",
                    imageStatus = "Motore veloce pronto. Scrivi un prompt e premi Genera.",
                    error = if (isHeavyImageModel(model) && !isPhoneFastImage(model)) {
                        "Janus/SD non entra nella RAM del telefono (un file da ~1 GB). Non lo carico. Premi Genera: è immediato."
                    } else {
                        null
                    },
                )
            }
            imageEngine.setStatus("Motore veloce pronto. Scrivi un prompt e premi Genera.")
            return
        }
        imageLoadJob = viewModelScope.launch {
            val token = _ui.value.hfToken.ifBlank { null }
            imageEngine.resetProgress()
            _ui.update {
                it.copy(
                    busy = true,
                    error = null,
                    selectedModelId = model.id,
                    imageDownloading = true,
                    imageProgress = 0.01f,
                    imageDownloadLabel = "Preparazione download…",
                    downloadProgress = it.downloadProgress + (model.id to 0.01f),
                )
            }
            var localBase: String? = null
            try {
                val already = withContext(Dispatchers.IO) {
                    downloader.isImageRepoReady(model.repo)
                }
                if (!already) {
                    val files = withContext(Dispatchers.IO) {
                        val tree = hfApi.listRepoTree(model.repo, token)
                        hfApi.filesForImageDownload(tree, model.file.ifBlank { "q4" })
                    }
                    val tooBig = files.any { it.size > 350L * 1024 * 1024 }
                    if (tooBig) {
                        throw IllegalStateException(
                            "Questo modello ha file da oltre 350 MB: il telefono non può caricarli in memoria. Usa Immagini veloci e premi Genera.",
                        )
                    }
                    if (files.isEmpty()) {
                        _ui.update {
                            it.copy(imageDownloadLabel = "Nessun file ONNX trovato, provo dal browser…")
                        }
                    } else {
                        val totalMb = files.sumOf { it.size }.toDouble() / (1024.0 * 1024.0)
                        _ui.update {
                            it.copy(
                                imageDownloadLabel = "0/${files.size} file · ${String.format("%.0f", totalMb)} MB",
                                imageStatus = "Download ${files.size} file ONNX…",
                            )
                        }
                        imageEngine.setStatus("Download ${files.size} file da Hugging Face…")
                        withContext(Dispatchers.IO) {
                            downloader.downloadRepoFiles(model.repo, files, token) { p ->
                                val fraction = if (p.totalBytes > 0) {
                                    (p.bytesRead.toFloat() / p.totalBytes.toFloat()).coerceIn(0f, 0.90f)
                                } else if (p.fileCount > 0) {
                                    (p.fileIndex.toFloat() / p.fileCount.toFloat()).coerceIn(0f, 0.90f)
                                } else {
                                    0.05f
                                }
                                val name = p.currentFile.substringAfterLast('/')
                                val label = if (p.fileCount > 0) {
                                    "${p.fileIndex}/${p.fileCount} · $name"
                                } else {
                                    name
                                }
                                _ui.update { state ->
                                    state.copy(
                                        imageProgress = fraction,
                                        imageDownloadLabel = label,
                                        imageStatus = "Download immagini ${(fraction * 100).toInt()}% — $label",
                                        downloadProgress = state.downloadProgress + (model.id to fraction),
                                    )
                                }
                                imageEngine.setProgress(fraction)
                                imageEngine.setStatus("Download immagini ${(fraction * 100).toInt()}% — $label")
                            }
                        }
                        refreshDownloaded()
                    }
                } else if (largestLocalOnnx(model.repo) > 350L * 1024 * 1024) {
                    throw IllegalStateException(
                        "I file già scaricati sono troppo grandi per la RAM. Usa Immagini veloci e premi Genera.",
                    )
                }
                if (downloader.isImageRepoReady(model.repo)) {
                    localBase = "/models/"
                }
                _ui.update {
                    it.copy(
                        imageProgress = maxOf(it.imageProgress, 0.90f),
                        imageDownloadLabel = "Caricamento in memoria…",
                        imageStatus = "File scaricati. Carico il modello…",
                        downloadProgress = it.downloadProgress + (model.id to maxOf(it.imageProgress, 0.90f)),
                    )
                }
                imageEngine.setProgress(maxOf(_ui.value.imageProgress, 0.90f))
                imageEngine.loadModel(
                    repo = model.repo,
                    dtype = model.file.ifBlank { "q4" },
                    token = token,
                    localBase = localBase,
                )
                _ui.update {
                    it.copy(
                        loadedImageModel = model.repo,
                        imageProgress = 1f,
                        imageDownloadLabel = "Completato",
                        downloadProgress = it.downloadProgress + (model.id to 1f),
                    )
                }
            } catch (e: Exception) {
                _ui.update {
                    it.copy(
                        error = friendlyImageError(e.message),
                        loadedImageModel = "veloce",
                        imageStatus = "Motore veloce pronto. Premi Genera.",
                    )
                }
            } finally {
                _ui.update {
                    it.copy(
                        busy = false,
                        imageDownloading = false,
                    )
                }
            }
        }
    }

    fun generateImage() {
        val prompt = _ui.value.imagePrompt.trim()
        if (prompt.isEmpty()) {
            _ui.update { it.copy(error = "Scrivi un prompt per l'immagine.") }
            return
        }
        viewModelScope.launch {
            _ui.update { it.copy(generatingImage = true, error = null, imageStatus = "Generazione…") }
            try {
                val localReady = _ui.value.loadedImageModel != null &&
                    _ui.value.loadedImageModel != "veloce" &&
                    imageEngine.loadedModel.value != null
                val path = if (localReady) {
                    try {
                        val dataUrl = imageEngine.generate(prompt)
                        withContext(Dispatchers.IO) { saveDataUrl(dataUrl) }
                    } catch (e: Exception) {
                        withContext(Dispatchers.IO) {
                            phoneImages.generate(prompt) { msg ->
                                _ui.update { it.copy(imageStatus = msg) }
                            }
                        }
                    }
                } else {
                    withContext(Dispatchers.IO) {
                        phoneImages.generate(prompt) { msg ->
                            _ui.update { it.copy(imageStatus = msg) }
                        }
                    }
                }
                _ui.update {
                    it.copy(
                        lastImagePath = path,
                        generatingImage = false,
                        loadedImageModel = it.loadedImageModel ?: "veloce",
                        imageStatus = "Immagine pronta",
                    )
                }
            } catch (e: Exception) {
                _ui.update {
                    it.copy(
                        generatingImage = false,
                        error = friendlyImageError(e.message),
                        imageStatus = "Generazione fallita",
                    )
                }
            }
        }
    }

    private fun isPhoneFastImage(model: HfModel): Boolean {
        return model.id == "fast-phone" || model.repo.equals("phone/fast", ignoreCase = true)
    }

    private fun isHeavyImageModel(model: HfModel): Boolean {
        if (model.kind != ModelKind.IMAGE) return false
        val blob = (model.repo + " " + model.name + " " + model.id).lowercase()
        return blob.contains("janus") ||
            blob.contains("stable-diffusion") ||
            blob.contains("sd21") ||
            blob.contains("diffusion")
    }

    private fun largestLocalOnnx(repo: String): Long {
        val dir = downloader.imageRepoDir(repo)
        if (!dir.isDirectory) return 0L
        return dir.walkTopDown()
            .filter { it.isFile && it.name.contains(".onnx") }
            .maxOfOrNull { it.length() } ?: 0L
    }

    private fun friendlyImageError(message: String?): String {
        val msg = message.orEmpty()
        if (
            msg.contains("allocate a buffer", ignoreCase = true) ||
            msg.contains("Can't create a session", ignoreCase = true) ||
            msg.contains("failed to allocate", ignoreCase = true)
        ) {
            return "Il modello è troppo grande per la RAM del telefono (un pezzo da ~1 GB). Non serve caricarlo: premi Genera, usa il motore veloce."
        }
        return message ?: "Operazione immagini fallita"
    }

    private fun saveDataUrl(dataUrl: String): String {
        val b64 = dataUrl.substringAfter("base64,", missingDelimiterValue = "")
        if (b64.isBlank()) throw IllegalStateException("Immagine non valida")
        val bytes = Base64.decode(b64, Base64.DEFAULT)
        BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
            ?: throw IllegalStateException("PNG non decodificabile")
        val out = File(imagesDir, "img-${System.currentTimeMillis()}.png")
        out.writeBytes(bytes)
        return out.absolutePath
    }

    private fun rememberCustom(model: HfModel) {
        val current = _ui.value.customModels.toMutableList()
        current.removeAll { it.id == model.id || (it.repo == model.repo && it.file == model.file) }
        current.add(0, model)
        val trimmed = current.take(30)
        _ui.update { it.copy(customModels = trimmed) }
        prefs.edit().putString(KEY_CUSTOM, serializeCustom(trimmed)).apply()
    }

    private fun loadCustomModels(): List<HfModel> {
        val raw = prefs.getString(KEY_CUSTOM, null) ?: return emptyList()
        return try {
            val arr = JSONArray(raw)
            (0 until arr.length()).map { i ->
                val o = arr.getJSONObject(i)
                HfModel(
                    id = o.optString("id"),
                    name = o.optString("name"),
                    repo = o.optString("repo"),
                    file = o.optString("file"),
                    sizeLabel = o.optString("sizeLabel", "custom"),
                    description = o.optString("description", ""),
                    tags = o.optString("tags").split(',').filter { it.isNotBlank() },
                    kind = if (o.optString("kind") == "IMAGE") ModelKind.IMAGE else ModelKind.LLM,
                )
            }
        } catch (_: Exception) {
            emptyList()
        }
    }

    private fun serializeCustom(models: List<HfModel>): String {
        val arr = JSONArray()
        models.forEach { m ->
            arr.put(
                JSONObject()
                    .put("id", m.id)
                    .put("name", m.name)
                    .put("repo", m.repo)
                    .put("file", m.file)
                    .put("sizeLabel", m.sizeLabel)
                    .put("description", m.description)
                    .put("tags", m.tags.joinToString(","))
                    .put("kind", m.kind.name),
            )
        }
        return arr.toString()
    }

    fun sendChat(userOverride: String? = null, fromAutoFix: Boolean = false) {
        val state = _ui.value
        val userText = (userOverride ?: state.chatInput).trim()
        if (userText.isEmpty() || state.busy) return
        if (state.loadedModelLabel == null) {
            _ui.update { it.copy(error = "Carica prima un modello dalla scheda Modelli.") }
            return
        }

        val casual = isCasualChat(userText) && !fromAutoFix
        val prompt = buildPrompt(state.code, userText, state.lastCompile, casual)
        val maxTokens = if (casual) 64 else 192
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
                val answer = engine.complete(prompt, maxTokens = maxTokens)
                val cleaned = CodeExtractor.cleanReply(answer)
                val extracted = if (!casual && !fromAutoFix) {
                    CodeExtractor.extractBestCode(cleaned)
                } else {
                    null
                }
                _ui.update { uiState ->
                    val msgs = uiState.messages.toMutableList()
                    if (msgs.isNotEmpty() && msgs.last().role == "assistant") {
                        msgs[msgs.lastIndex] = ChatMessage(
                            "assistant",
                            cleaned.ifBlank { "(nessuna risposta)" },
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

    fun refreshLocalModels() {
        refreshDownloaded()
    }

    private fun refreshDownloaded() {
        val all = ModelCatalog.models + _ui.value.customModels
        val local = downloader.listDownloaded(all)
        val downloaded = local.map { it.id }.toSet() +
            all.filter { it.kind == ModelKind.LLM && downloader.isDownloaded(it.repo, it.file) }
                .map { it.id }
                .toSet() +
            all.filter { it.kind == ModelKind.IMAGE && downloader.isImageRepoReady(it.repo) }
                .map { it.id }
                .toSet()
        _ui.update { it.copy(downloadedIds = downloaded, downloadedModels = local) }
    }

    private fun isCasualChat(text: String): Boolean {
        val t = text.lowercase().trim()
        if (t.length > 40 || t.contains('\n')) return false
        val casual = listOf(
            "ciao", "hey", "salve", "hola", "hello", "hi", "ok", "grazie",
            "buongiorno", "buonasera", "come stai", "chi sei", "thanks",
        )
        return casual.any { key ->
            t == key || t == "$key!" || t == "$key?" || t.startsWith("$key ")
        }
    }

    private fun buildPrompt(
        code: String,
        userText: String,
        lastCompile: CompileResult?,
        casual: Boolean,
    ): String {
        if (casual) {
            return """
                <|im_start|>system
                Sei CodeCompanion. Rispondi in italiano, massimo 2 frasi. Non scrivere codice. Non ripetere il prompt.
                <|im_end|>
                <|im_start|>user
                $userText
                <|im_end|>
                <|im_start|>assistant
                
            """.trimIndent()
        }
        val compileInfo = if (lastCompile == null) {
            "Nessuna compilazione recente."
        } else {
            "ok=${lastCompile.ok}"
        }
        return """
            <|im_start|>system
            Sei un assistente di programmazione. Rispondi in italiano, in modo breve.
            Se proponi codice, mettilo in un unico blocco markdown. Non ripetere queste istruzioni.
            <|im_end|>
            <|im_start|>user
            Codice aperto:
            ```
            $code
            ```
            Compilazione: $compileInfo
            $userText
            <|im_end|>
            <|im_start|>assistant
            
        """.trimIndent()
    }
}
