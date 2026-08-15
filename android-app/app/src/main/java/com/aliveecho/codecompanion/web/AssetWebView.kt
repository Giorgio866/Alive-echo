package com.aliveecho.codecompanion.web

import android.annotation.SuppressLint
import android.content.Context
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.webkit.WebViewAssetLoader
import java.io.File
import java.io.FileInputStream
import java.net.URLDecoder

object AssetWebView {
    const val ORIGIN = "https://appassets.androidplatform.net"

    fun assetUrl(path: String): String = "$ORIGIN/assets/$path"

    fun modelUrl(fileName: String): String = "$ORIGIN/models/$fileName"

    @SuppressLint("SetJavaScriptEnabled")
    fun configure(context: Context, webView: WebView) {
        val app = context.applicationContext
        val modelsDir = File(app.filesDir, "models").apply { mkdirs() }
        val builder = WebViewAssetLoader.Builder()
            .setDomain("appassets.androidplatform.net")
            .addPathHandler("/assets/", WebViewAssetLoader.AssetsPathHandler(app))
            .addPathHandler("/models/") { path -> serveModelFile(modelsDir, path) }
        val loader = builder.build()

        webView.settings.javaScriptEnabled = true
        webView.settings.domStorageEnabled = true
        webView.settings.databaseEnabled = true
        webView.settings.allowFileAccess = false
        webView.settings.allowContentAccess = false
        webView.settings.cacheMode = WebSettings.LOAD_DEFAULT
        webView.settings.mixedContentMode = WebSettings.MIXED_CONTENT_ALWAYS_ALLOW
        @Suppress("DEPRECATION")
        webView.settings.allowFileAccessFromFileURLs = false
        @Suppress("DEPRECATION")
        webView.settings.allowUniversalAccessFromFileURLs = false

        webView.webViewClient = object : WebViewClient() {
            override fun shouldInterceptRequest(
                view: WebView?,
                request: WebResourceRequest,
            ): WebResourceResponse? {
                loader.shouldInterceptRequest(request.url)?.let { return it }
                val url = request.url
                if (url.host == "appassets.androidplatform.net" && url.path?.startsWith("/models/") == true) {
                    val rel = url.path.orEmpty().removePrefix("/models/")
                    return serveModelFile(modelsDir, rel)
                }
                return null
            }
        }
    }

    fun loadAsset(webView: WebView, assetPath: String) {
        webView.loadUrl(assetUrl(assetPath))
    }

    private fun serveModelFile(modelsDir: File, rawPath: String): WebResourceResponse? {
        return try {
            val decoded = URLDecoder.decode(rawPath, "UTF-8").trimStart('/')
            if (decoded.isBlank() || decoded.contains("..")) return null
            val file = File(modelsDir, decoded)
            val root = modelsDir.canonicalPath + File.separator
            if (!file.canonicalPath.startsWith(root) || !file.isFile) return null
            val mime = when {
                decoded.endsWith(".json", true) -> "application/json"
                decoded.endsWith(".txt", true) -> "text/plain"
                decoded.endsWith(".onnx", true) -> "application/octet-stream"
                decoded.endsWith(".onnx_data", true) -> "application/octet-stream"
                decoded.endsWith(".gguf", true) -> "application/octet-stream"
                else -> "application/octet-stream"
            }
            WebResourceResponse(mime, null, FileInputStream(file))
        } catch (_: Exception) {
            null
        }
    }
}
