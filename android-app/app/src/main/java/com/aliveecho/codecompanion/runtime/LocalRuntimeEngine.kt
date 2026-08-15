package com.aliveecho.codecompanion.runtime

import android.annotation.SuppressLint
import android.content.Context
import android.view.ViewGroup
import android.webkit.JavascriptInterface
import android.webkit.WebView
import com.aliveecho.codecompanion.data.CompileResult
import com.aliveecho.codecompanion.web.AssetWebView
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.util.concurrent.atomic.AtomicReference
import kotlin.coroutines.resume

class LocalRuntimeEngine {
    private val webViewRef = AtomicReference<WebView?>(null)
    private val _ready = MutableStateFlow(false)
    val ready: StateFlow<Boolean> = _ready.asStateFlow()

    private val _status = MutableStateFlow("Runtime locale non avviato")
    val status: StateFlow<String> = _status.asStateFlow()

    private var pending: ((CompileResult) -> Unit)? = null

    @SuppressLint("SetJavaScriptEnabled")
    fun attachWebView(context: Context): WebView {
        webViewRef.get()?.let { return it }
        val webView = WebView(context).apply {
            layoutParams = ViewGroup.LayoutParams(1, 1)
            addJavascriptInterface(Bridge(), "LocalBridge")
            AssetWebView.configure(context, this)
            AssetWebView.loadAsset(this, "runtime/runtime.html")
        }
        webViewRef.set(webView)
        return webView
    }

    suspend fun run(language: String, code: String): CompileResult = withContext(Dispatchers.Main) {
        val webView = webViewRef.get()
            ?: return@withContext CompileResult(
                ok = false,
                exitCode = -1,
                stdout = "",
                stderr = "Runtime locale non pronto",
                durationMs = 0,
                language = language,
                phase = "local",
                errorMessage = "WebView assente",
            )
        if (!_ready.value) {
            // wait briefly for ready
            var waits = 0
            while (!_ready.value && waits < 40) {
                kotlinx.coroutines.delay(50)
                waits++
            }
        }
        if (!_ready.value) {
            return@withContext CompileResult(
                ok = false,
                exitCode = -1,
                stdout = "",
                stderr = "Runtime locale ancora in avvio",
                durationMs = 0,
                language = language,
                phase = "local",
            )
        }

        val started = System.currentTimeMillis()
        suspendCancellableCoroutine { cont ->
            pending = { result ->
                pending = null
                cont.resume(
                    result.copy(durationMs = (System.currentTimeMillis() - started).toInt()),
                )
            }
            val quotedLang = JSONObject.quote(language)
            val quotedCode = JSONObject.quote(code)
            val js = """
                (async function(){
                  try {
                    const raw = await window.runCode($quotedLang, $quotedCode);
                    LocalBridge.onResult(String(raw));
                  } catch (e) {
                    LocalBridge.onResult(JSON.stringify({
                      ok:false, exitCode:1, stdout:'', stderr:String(e),
                      language:$quotedLang, phase:'local'
                    }));
                  }
                })();
            """.trimIndent()
            webView.evaluateJavascript(js, null)
            cont.invokeOnCancellation { pending = null }
        }
    }

    private inner class Bridge {
        @JavascriptInterface
        fun onReady(msg: String) {
            _ready.value = true
            _status.value = "Runtime locale pronto"
        }

        @JavascriptInterface
        fun onStatus(msg: String) {
            _status.value = msg
        }

        @JavascriptInterface
        fun onResult(raw: String) {
            val result = try {
                val json = JSONObject(raw)
                CompileResult(
                    ok = json.optBoolean("ok"),
                    exitCode = json.optInt("exitCode", 1),
                    stdout = json.optString("stdout"),
                    stderr = json.optString("stderr"),
                    durationMs = json.optInt("durationMs", 0),
                    language = json.optString("language"),
                    phase = json.optString("phase", "local"),
                )
            } catch (e: Exception) {
                CompileResult(
                    ok = false,
                    exitCode = 1,
                    stdout = "",
                    stderr = e.message ?: "Parse error",
                    durationMs = 0,
                    language = null,
                    phase = "local",
                    errorMessage = e.message,
                )
            }
            pending?.invoke(result)
        }
    }
}
