package com.aliveecho.codecompanion.image

import android.annotation.SuppressLint
import android.content.Context
import android.view.ViewGroup
import android.webkit.JavascriptInterface
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.util.concurrent.atomic.AtomicReference
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

class ImageEngine {
    private val webViewRef = AtomicReference<WebView?>(null)

    private val _ready = MutableStateFlow(false)
    val ready: StateFlow<Boolean> = _ready.asStateFlow()

    private val _status = MutableStateFlow("Motore immagini non avviato")
    val status: StateFlow<String> = _status.asStateFlow()

    private val _loadedModel = MutableStateFlow<String?>(null)
    val loadedModel: StateFlow<String?> = _loadedModel.asStateFlow()

    private var loadContinuation: ((Result<String>) -> Unit)? = null
    private var genContinuation: ((Result<String>) -> Unit)? = null

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
            addJavascriptInterface(Bridge(), "ImageBridge")
            webViewClient = object : WebViewClient() {}
            loadUrl("file:///android_asset/image/engine.html")
        }
        webViewRef.set(webView)
        return webView
    }

    suspend fun loadModel(repo: String, dtype: String, token: String?): String =
        withContext(Dispatchers.Main) {
            val webView = webViewRef.get() ?: error("WebView immagini non pronto")
            var waits = 0
            while (!_ready.value && waits < 80) {
                delay(50)
                waits++
            }
            if (!_ready.value) error("Motore immagini non ancora pronto")
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
                        const m = await window.loadImageModel(
                          ${JSONObject.quote(repo)},
                          ${JSONObject.quote(dtype)},
                          ${JSONObject.quote(token ?: "")}
                        );
                        ImageBridge.onModelLoaded(String(m));
                      } catch(e) {
                        ImageBridge.onError(String(e));
                      }
                    })();
                """.trimIndent()
                webView.evaluateJavascript(js, null)
                cont.invokeOnCancellation { loadContinuation = null }
            }
        }

    suspend fun generate(prompt: String, steps: Int = 20): String = withContext(Dispatchers.Main) {
        val webView = webViewRef.get() ?: error("WebView immagini non pronto")
        if (_loadedModel.value == null) error("Nessun modello immagini caricato")
        suspendCancellableCoroutine { cont ->
            genContinuation = { result ->
                genContinuation = null
                result.fold(
                    onSuccess = { cont.resume(it) },
                    onFailure = { cont.resumeWithException(it) },
                )
            }
            val js = """
                (async function(){
                  try {
                    const url = await window.generateImage(${JSONObject.quote(prompt)}, $steps);
                    ImageBridge.onImage(String(url));
                  } catch(e) {
                    ImageBridge.onError(String(e));
                  }
                })();
            """.trimIndent()
            webView.evaluateJavascript(js, null)
            cont.invokeOnCancellation { genContinuation = null }
        }
    }

    private inner class Bridge {
        @JavascriptInterface
        fun onReady(msg: String) {
            _ready.value = true
            _status.value = "Motore immagini pronto"
        }

        @JavascriptInterface
        fun onStatus(msg: String) {
            _status.value = msg
        }

        @JavascriptInterface
        fun onModelLoaded(model: String) {
            _loadedModel.value = model
            _status.value = "Modello immagini caricato"
            loadContinuation?.invoke(Result.success(model))
        }

        @JavascriptInterface
        fun onImage(dataUrl: String) {
            genContinuation?.invoke(Result.success(dataUrl))
        }

        @JavascriptInterface
        fun onError(msg: String) {
            _status.value = msg
            loadContinuation?.invoke(Result.failure(IllegalStateException(msg)))
            genContinuation?.invoke(Result.failure(IllegalStateException(msg)))
        }
    }
}
