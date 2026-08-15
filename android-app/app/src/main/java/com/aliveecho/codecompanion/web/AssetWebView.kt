package com.aliveecho.codecompanion.web

import android.annotation.SuppressLint
import android.content.Context
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.webkit.WebViewAssetLoader

object AssetWebView {
    const val ORIGIN = "https://appassets.androidplatform.net"

    fun assetUrl(path: String): String = "$ORIGIN/assets/$path"

    @SuppressLint("SetJavaScriptEnabled")
    fun configure(context: Context, webView: WebView) {
        val loader = WebViewAssetLoader.Builder()
            .setDomain("appassets.androidplatform.net")
            .addPathHandler("/assets/", WebViewAssetLoader.AssetsPathHandler(context.applicationContext))
            .build()

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
                return loader.shouldInterceptRequest(request.url)
            }
        }
    }

    fun loadAsset(webView: WebView, assetPath: String) {
        webView.loadUrl(assetUrl(assetPath))
    }
}
