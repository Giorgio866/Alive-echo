# Keep WebView JS bridge
-keepclassmembers class com.aliveecho.codecompanion.inference.InferenceBridge {
    @android.webkit.JavascriptInterface <methods>;
}
