package com.aliveecho.codecompanion

import android.os.Bundle
import android.view.ViewGroup
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.viewModels
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.size
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import com.aliveecho.codecompanion.ui.CodeCompanionApp

class MainActivity : ComponentActivity() {
    private val viewModel: AppViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            val state by viewModel.ui.collectAsState()
            MaterialTheme(
                colorScheme = lightColorScheme(
                    primary = Color(0xFF2F6F4E),
                    onPrimary = Color.White,
                    background = Color(0xFFF4EFE6),
                    surface = Color(0xFFF4EFE6),
                ),
            ) {
                Box(Modifier.fillMaxSize()) {
                    CodeCompanionApp(
                        state = state,
                        onCodeChange = viewModel::updateCode,
                        onLanguageChange = viewModel::updateLanguage,
                        onChatInputChange = viewModel::updateChatInput,
                        onSendChat = { viewModel.sendChat() },
                        onSendCodeToChat = viewModel::sendCodeToChat,
                        onDownload = viewModel::downloadModel,
                        onLoad = viewModel::loadModel,
                        onClearError = viewModel::clearError,
                        onCompileModeChange = viewModel::setCompileMode,
                        onServerUrlChange = viewModel::updateServerUrl,
                        onAutoCompileChange = viewModel::setAutoCompile,
                        onAutoFixChange = viewModel::setAutoFixOnError,
                        onCheckServer = viewModel::checkServer,
                        onCompileNow = viewModel::compileNow,
                        onHfQueryChange = viewModel::updateHfQuery,
                        onHfTokenChange = viewModel::updateHfToken,
                        onSearchHf = viewModel::searchHuggingFace,
                        onPickHfRepo = viewModel::pickHfRepo,
                        onAddCustom = viewModel::addCustomGguf,
                        onImagePromptChange = viewModel::updateImagePrompt,
                        onGenerateImage = viewModel::generateImage,
                        onRefreshLocal = viewModel::refreshLocalModels,
                        onLocalQueryChange = viewModel::updateLocalQuery,
                        onImportUri = viewModel::importFromUri,
                    )
                    HiddenWebEngines(viewModel)
                }
            }
        }
    }
}

@Composable
private fun HiddenWebEngines(viewModel: AppViewModel) {
    AndroidView(
        factory = { context ->
            viewModel.engine.attachWebView(context).also { webView ->
                (webView.parent as? ViewGroup)?.removeView(webView)
                webView.layoutParams = ViewGroup.LayoutParams(1, 1)
                webView.alpha = 0f
            }
        },
        modifier = Modifier.size(1.dp),
    )
    AndroidView(
        factory = { context ->
            viewModel.localRuntime.attachWebView(context).also { webView ->
                (webView.parent as? ViewGroup)?.removeView(webView)
                webView.layoutParams = ViewGroup.LayoutParams(1, 1)
                webView.alpha = 0f
            }
        },
        modifier = Modifier.size(1.dp),
    )
    AndroidView(
        factory = { context ->
            viewModel.imageEngine.attachWebView(context).also { webView ->
                (webView.parent as? ViewGroup)?.removeView(webView)
                webView.layoutParams = ViewGroup.LayoutParams(1, 1)
                webView.alpha = 0f
            }
        },
        modifier = Modifier.size(1.dp),
    )
}
