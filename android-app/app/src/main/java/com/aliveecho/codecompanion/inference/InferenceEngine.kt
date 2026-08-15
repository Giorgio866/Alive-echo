package com.aliveecho.codecompanion.inference

import android.annotation.SuppressLint
import android.content.Context
import android.view.ViewGroup
import android.webkit.JavascriptInterface
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.util.concurrent.atomic.AtomicReference
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

class InferenceEngine(context: Context) {
    private val appContext = context.applicationContext

    private val _engineReady = MutableStateFlow(false)
    val engineReady: StateFlow<Boolean> = _engineReady.asStateFlow()

    private val _status = MutableStateFlow("Motore non avviato")
    val status: StateFlow<String> = _status.asStateFlow()

    private val _loadedModel = MutableStateFlow<String?>(null)
    val loadedModel: StateFlow<String?> = _loadedModel.asStateFlow()

    private val _tokenStream = MutableSharedFlow<String>(extraBufferCapacity = 64)
    val tokenStream: SharedFlow<String> = _tokenStream.asSharedFlow()

    private val webViewRef = AtomicReference<WebView?>(null)
    private var loadContinuation: ((Result<String>) -> Unit)? = null
    private var chatContinuation: ((Result<String>) -> Unit)? = null

    @SuppressLint("SetJavaScriptEnabled")
    fun attachWebView(context: Context): WebView {
        webViewRef.get()?.let { return it }
        val webView = WebView(context).apply {
            layoutParams = ViewGroup.LayoutParams(1, 1)
            settings.javaScriptEnabled = true
            settings.domStorageEnabled = true
            settings.allowFileAccess = true
            settings.allowContentAccess = true
            settings.cacheMode = WebSettings.LOAD_DEFAULT
            settings.mixedContentMode = WebSettings.MIXED_CONTENT_ALWAYS_ALLOW
            addJavascriptInterface(Bridge(), "AndroidBridge")
            webViewClient = object : WebViewClient() {}
            loadUrl("file:///android_asset/inference/engine.html")
        }
        webViewRef.set(webView)
        return webView
    }

    suspend fun loadModel(repo: String, file: String): String = withContext(Dispatchers.Main) {
        val webView = webViewRef.get() ?: error("WebView non pronto")
        if (!_engineReady.value) error("Motore AI non ancora pronto")
        suspendCancellableCoroutine { cont ->
            loadContinuation = { result ->
                loadContinuation = null
                result.fold(
                    onSuccess = { cont.resume(it) },
                    onFailure = { cont.resumeWithException(it) },
                )
            }
            val js = """
                (async function(){
                  try {
                    const m = await window.loadModel(${JSONObject.quote(repo)}, ${JSONObject.quote(file)});
                    AndroidBridge.onModelLoaded(String(m));
                  } catch(e) {
                    AndroidBridge.onError(String(e));
                  }
                })();
            """.trimIndent()
            webView.evaluateJavascript(js, null)
            cont.invokeOnCancellation { loadContinuation = null }
        }
    }

    suspend fun complete(prompt: String, maxTokens: Int = 256): String = withContext(Dispatchers.Main) {
        val webView = webViewRef.get() ?: error("WebView non pronto")
        if (_loadedModel.value == null) error("Nessun modello caricato")
        suspendCancellableCoroutine { cont ->
            chatContinuation = { result ->
                chatContinuation = null
                result.fold(
                    onSuccess = { cont.resume(it) },
                    onFailure = { cont.resumeWithException(it) },
                )
            }
            val js = """
                (async function(){
                  try {
                    const t = await window.chat(${JSONObject.quote(prompt)}, $maxTokens);
                    AndroidBridge.onComplete(String(t));
                  } catch(e) {
                    AndroidBridge.onError(String(e));
                  }
                })();
            """.trimIndent()
            webView.evaluateJavascript(js, null)
            cont.invokeOnCancellation { chatContinuation = null }
        }
    }

    private inner class Bridge {
        @JavascriptInterface
        fun onEngineReady() {
            _engineReady.value = true
            _status.value = "Motore pronto"
        }

        @JavascriptInterface
        fun onStatus(msg: String) {
            _status.value = msg
        }

        @JavascriptInterface
        fun onLog(msg: String) {
            // reserved for debug
        }

        @JavascriptInterface
        fun onModelLoaded(model: String) {
            _loadedModel.value = model
            _status.value = "Modello caricato"
            loadContinuation?.invoke(Result.success(model))
        }

        @JavascriptInterface
        fun onToken(text: String) {
            _tokenStream.tryEmit(text)
        }

        @JavascriptInterface
        fun onComplete(text: String) {
            chatContinuation?.invoke(Result.success(text))
        }

        @JavascriptInterface
        fun onError(msg: String) {
            _status.value = msg
            loadContinuation?.invoke(Result.failure(IllegalStateException(msg)))
            chatContinuation?.invoke(Result.failure(IllegalStateException(msg)))
        }
    }
}
