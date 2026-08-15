package com.aliveecho.codecompanion.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Chat
import androidx.compose.material.icons.filled.Code
import androidx.compose.material.icons.filled.Download
import androidx.compose.material.icons.filled.Memory
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Send
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.aliveecho.codecompanion.AppUiState
import com.aliveecho.codecompanion.ChatMessage
import com.aliveecho.codecompanion.HfModel
import com.aliveecho.codecompanion.ModelCatalog

private val Ink = Color(0xFF101820)
private val Paper = Color(0xFFF4EFE6)
private val Moss = Color(0xFF2F6F4E)
private val MossDark = Color(0xFF1F4D36)
private val Sand = Color(0xFFE7DCC8)
private val Smoke = Color(0xFF5C6670)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CodeCompanionApp(
    state: AppUiState,
    onCodeChange: (String) -> Unit,
    onChatInputChange: (String) -> Unit,
    onSendChat: () -> Unit,
    onSendCodeToChat: () -> Unit,
    onDownload: (HfModel) -> Unit,
    onLoad: (HfModel) -> Unit,
    onClearError: () -> Unit,
) {
    var tab by rememberSaveable { mutableIntStateOf(0) }

    Scaffold(
        containerColor = Paper,
        topBar = {
            TopAppBar(
                title = {
                    Column {
                        Text(
                            "CodeCompanion",
                            fontWeight = FontWeight.Bold,
                            color = Ink,
                        )
                        Text(
                            state.engineStatus,
                            style = MaterialTheme.typography.bodySmall,
                            color = Smoke,
                            maxLines = 1,
                        )
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Paper),
            )
        },
        bottomBar = {
            NavigationBar(containerColor = Sand) {
                NavigationBarItem(
                    selected = tab == 0,
                    onClick = { tab = 0 },
                    icon = { Icon(Icons.Default.Code, contentDescription = null) },
                    label = { Text("Editor") },
                )
                NavigationBarItem(
                    selected = tab == 1,
                    onClick = { tab = 1 },
                    icon = { Icon(Icons.Default.Chat, contentDescription = null) },
                    label = { Text("Chat") },
                )
                NavigationBarItem(
                    selected = tab == 2,
                    onClick = { tab = 2 },
                    icon = { Icon(Icons.Default.Memory, contentDescription = null) },
                    label = { Text("Modelli") },
                )
            }
        },
    ) { padding ->
        Column(
            Modifier
                .fillMaxSize()
                .padding(padding),
        ) {
            if (state.error != null) {
                Row(
                    Modifier
                        .fillMaxWidth()
                        .background(Color(0xFFFFE2E0))
                        .padding(12.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(state.error, color = Color(0xFF8A1F17), modifier = Modifier.weight(1f))
                    TextButton(onClick = onClearError) { Text("OK") }
                }
            }
            when (tab) {
                0 -> EditorScreen(state, onCodeChange, onSendCodeToChat, onGoChat = { tab = 1 })
                1 -> ChatScreen(state, onChatInputChange, onSendChat)
                else -> ModelsScreen(state, onDownload, onLoad)
            }
        }
    }
}

@Composable
private fun EditorScreen(
    state: AppUiState,
    onCodeChange: (String) -> Unit,
    onSendCodeToChat: () -> Unit,
    onGoChat: () -> Unit,
) {
    Column(
        Modifier
            .fillMaxSize()
            .padding(16.dp),
    ) {
        Text(
            "Editor",
            style = MaterialTheme.typography.headlineSmall,
            fontWeight = FontWeight.SemiBold,
            color = Ink,
        )
        Text(
            "Scrivi codice qui, poi invialo alla chat AI.",
            color = Smoke,
            style = MaterialTheme.typography.bodyMedium,
        )
        Spacer(Modifier.height(12.dp))
        Box(
            Modifier
                .weight(1f)
                .fillMaxWidth()
                .background(Ink, RoundedCornerShape(12.dp))
                .padding(14.dp),
        ) {
            BasicTextField(
                value = state.code,
                onValueChange = onCodeChange,
                textStyle = TextStyle(
                    color = Color(0xFFE8EEF2),
                    fontFamily = FontFamily.Monospace,
                    fontSize = 14.sp,
                    lineHeight = 20.sp,
                ),
                cursorBrush = SolidColor(Color(0xFF9BE7C4)),
                modifier = Modifier
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState()),
            )
        }
        Spacer(Modifier.height(12.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Button(
                onClick = {
                    onSendCodeToChat()
                    onGoChat()
                },
                colors = ButtonDefaults.buttonColors(containerColor = Moss),
                modifier = Modifier.weight(1f),
            ) {
                Icon(Icons.Default.Send, contentDescription = null)
                Spacer(Modifier.width(8.dp))
                Text("Invia ad AI")
            }
        }
    }
}

@Composable
private fun ChatScreen(
    state: AppUiState,
    onChatInputChange: (String) -> Unit,
    onSendChat: () -> Unit,
) {
    Column(
        Modifier
            .fillMaxSize()
            .padding(16.dp),
    ) {
        Text(
            "Chat AI locale",
            style = MaterialTheme.typography.headlineSmall,
            fontWeight = FontWeight.SemiBold,
            color = Ink,
        )
        Text(
            state.loadedModelLabel ?: "Nessun modello caricato",
            color = Smoke,
            style = MaterialTheme.typography.bodySmall,
        )
        Spacer(Modifier.height(8.dp))
        LazyColumn(
            modifier = Modifier
                .weight(1f)
                .fillMaxWidth(),
            verticalArrangement = Arrangement.spacedBy(8.dp),
            contentPadding = PaddingValues(bottom = 8.dp),
        ) {
            items(state.messages) { message ->
                MessageBubble(message)
            }
        }
        if (state.busy) {
            LinearProgressIndicator(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(bottom = 8.dp),
                color = Moss,
            )
        }
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            BasicTextField(
                value = state.chatInput,
                onValueChange = onChatInputChange,
                textStyle = TextStyle(color = Ink, fontSize = 16.sp),
                modifier = Modifier
                    .weight(1f)
                    .background(Sand, RoundedCornerShape(12.dp))
                    .padding(14.dp),
                decorationBox = { inner ->
                    if (state.chatInput.isEmpty()) {
                        Text("Chiedi aiuto sul codice…", color = Smoke)
                    }
                    inner()
                },
            )
            Button(
                onClick = onSendChat,
                enabled = !state.busy && state.engineReady,
                colors = ButtonDefaults.buttonColors(containerColor = MossDark),
            ) {
                if (state.busy) {
                    CircularProgressIndicator(
                        modifier = Modifier
                            .height(18.dp)
                            .width(18.dp),
                        strokeWidth = 2.dp,
                        color = Color.White,
                    )
                } else {
                    Icon(Icons.Default.Send, contentDescription = "Invia")
                }
            }
        }
    }
}

@Composable
private fun MessageBubble(message: ChatMessage) {
    val isUser = message.role == "user"
    Column(
        Modifier.fillMaxWidth(),
        horizontalAlignment = if (isUser) Alignment.End else Alignment.Start,
    ) {
        Text(
            if (isUser) "Tu" else "AI",
            style = MaterialTheme.typography.labelMedium,
            color = Smoke,
        )
        Text(
            message.content,
            modifier = Modifier
                .background(
                    if (isUser) Moss.copy(alpha = 0.12f) else Sand,
                    RoundedCornerShape(12.dp),
                )
                .padding(12.dp),
            color = Ink,
            fontFamily = if (!isUser && message.content.contains("```")) {
                FontFamily.Monospace
            } else {
                FontFamily.Default
            },
        )
    }
}

@Composable
private fun ModelsScreen(
    state: AppUiState,
    onDownload: (HfModel) -> Unit,
    onLoad: (HfModel) -> Unit,
) {
    LazyColumn(
        Modifier
            .fillMaxSize()
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        item {
            Text(
                "Modelli Hugging Face",
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.SemiBold,
                color = Ink,
            )
            Text(
                "Solo APK: i modelli girano sul telefono. Usa file piccoli (Q4).",
                color = Smoke,
            )
            Spacer(Modifier.height(4.dp))
            Text(
                if (state.engineReady) "Motore AI pronto" else "Motore AI in avvio…",
                color = if (state.engineReady) Moss else Smoke,
                fontWeight = FontWeight.Medium,
            )
        }
        items(ModelCatalog.models) { model ->
            ModelCard(
                model = model,
                selected = state.selectedModelId == model.id,
                downloaded = model.id in state.downloadedIds,
                progress = state.downloadProgress[model.id],
                busy = state.busy,
                engineReady = state.engineReady,
                onDownload = { onDownload(model) },
                onLoad = { onLoad(model) },
            )
        }
    }
}

@Composable
private fun ModelCard(
    model: HfModel,
    selected: Boolean,
    downloaded: Boolean,
    progress: Float?,
    busy: Boolean,
    engineReady: Boolean,
    onDownload: () -> Unit,
    onLoad: () -> Unit,
) {
    Column(
        Modifier
            .fillMaxWidth()
            .background(if (selected) Moss.copy(alpha = 0.10f) else Sand, RoundedCornerShape(14.dp))
            .padding(14.dp),
    ) {
        Text(model.name, fontWeight = FontWeight.SemiBold, color = Ink)
        Text(model.sizeLabel + " · " + model.tags.joinToString(" · "), color = Smoke, fontSize = 12.sp)
        Spacer(Modifier.height(6.dp))
        Text(model.description, color = Ink)
        Spacer(Modifier.height(4.dp))
        Text("${model.repo}/${model.file}", color = Smoke, fontSize = 11.sp, fontFamily = FontFamily.Monospace)
        if (progress != null && progress < 1f) {
            Spacer(Modifier.height(8.dp))
            LinearProgressIndicator(progress = { progress }, modifier = Modifier.fillMaxWidth(), color = Moss)
        }
        Spacer(Modifier.height(10.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            OutlinedButton(onClick = onDownload, enabled = !busy) {
                Icon(Icons.Default.Download, contentDescription = null)
                Spacer(Modifier.width(6.dp))
                Text(if (downloaded) "Riscarica" else "Scarica")
            }
            Button(
                onClick = onLoad,
                enabled = !busy && engineReady,
                colors = ButtonDefaults.buttonColors(containerColor = Moss),
            ) {
                Icon(Icons.Default.PlayArrow, contentDescription = null)
                Spacer(Modifier.width(6.dp))
                Text(if (selected && downloaded) "Ricarica" else "Carica in AI")
            }
        }
    }
}
