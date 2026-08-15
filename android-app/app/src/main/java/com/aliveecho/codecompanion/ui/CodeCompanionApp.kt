package com.aliveecho.codecompanion.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Build
import androidx.compose.material.icons.filled.Chat
import androidx.compose.material.icons.filled.Code
import androidx.compose.material.icons.filled.Download
import androidx.compose.material.icons.filled.Memory
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Send
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.getValue
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
import com.aliveecho.codecompanion.CompileMode
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
    onLanguageChange: (String) -> Unit,
    onChatInputChange: (String) -> Unit,
    onSendChat: () -> Unit,
    onSendCodeToChat: () -> Unit,
    onDownload: (HfModel) -> Unit,
    onLoad: (HfModel) -> Unit,
    onClearError: () -> Unit,
    onCompileModeChange: (CompileMode) -> Unit,
    onServerUrlChange: (String) -> Unit,
    onAutoCompileChange: (Boolean) -> Unit,
    onAutoFixChange: (Boolean) -> Unit,
    onCheckServer: () -> Unit,
    onCompileNow: () -> Unit,
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
                        val compileHint = when {
                            state.compiling -> "Compilazione…"
                            state.lastCompile?.ok == true -> "Build OK"
                            state.lastCompile?.ok == false -> "Build errore"
                            else -> state.engineStatus
                        }
                        Text(
                            compileHint,
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
                    icon = { Icon(Icons.Default.Build, contentDescription = null) },
                    label = { Text("Build") },
                )
                NavigationBarItem(
                    selected = tab == 3,
                    onClick = { tab = 3 },
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
                0 -> EditorScreen(
                    state = state,
                    onCodeChange = onCodeChange,
                    onLanguageChange = onLanguageChange,
                    onSendCodeToChat = onSendCodeToChat,
                    onCompileNow = onCompileNow,
                    onGoChat = { tab = 1 },
                )
                1 -> ChatScreen(state, onChatInputChange, onSendChat)
                2 -> BuildScreen(
                    state = state,
                    onCompileModeChange = onCompileModeChange,
                    onServerUrlChange = onServerUrlChange,
                    onAutoCompileChange = onAutoCompileChange,
                    onAutoFixChange = onAutoFixChange,
                    onCheckServer = onCheckServer,
                    onCompileNow = onCompileNow,
                )
                else -> ModelsScreen(state, onDownload, onLoad)
            }
        }
    }
}

@Composable
private fun EditorScreen(
    state: AppUiState,
    onCodeChange: (String) -> Unit,
    onLanguageChange: (String) -> Unit,
    onSendCodeToChat: () -> Unit,
    onCompileNow: () -> Unit,
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
            if (state.compileMode == CompileMode.LOCAL) {
                "Esecuzione DENTRO l'app (Python / JavaScript)."
            } else {
                "Esecuzione sul PC remoto (scheda Build)."
            },
            color = Smoke,
            style = MaterialTheme.typography.bodyMedium,
        )
        Spacer(Modifier.height(8.dp))
        LanguageChips(state.language, onLanguageChange)
        Spacer(Modifier.height(8.dp))
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
        Spacer(Modifier.height(8.dp))
        CompileOutputBox(state)
        Spacer(Modifier.height(8.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Button(
                onClick = onCompileNow,
                colors = ButtonDefaults.buttonColors(containerColor = MossDark),
                modifier = Modifier.weight(1f),
            ) {
                Icon(Icons.Default.PlayArrow, contentDescription = null)
                Spacer(Modifier.width(6.dp))
                Text(if (state.compiling) "…" else "Compila")
            }
            Button(
                onClick = {
                    onSendCodeToChat()
                    onGoChat()
                },
                colors = ButtonDefaults.buttonColors(containerColor = Moss),
                modifier = Modifier.weight(1f),
            ) {
                Icon(Icons.Default.Send, contentDescription = null)
                Spacer(Modifier.width(6.dp))
                Text("Invia ad AI")
            }
        }
    }
}

@Composable
private fun LanguageChips(selected: String, onLanguageChange: (String) -> Unit) {
    val languages = listOf("python", "javascript", "java", "kotlin")
    Row(
        Modifier.horizontalScroll(rememberScrollState()),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        languages.forEach { lang ->
            FilterChip(
                selected = selected == lang,
                onClick = { onLanguageChange(lang) },
                label = { Text(lang) },
            )
        }
    }
}

@Composable
private fun CompileOutputBox(state: AppUiState) {
    val ok = state.lastCompile?.ok
    val bg = when (ok) {
        true -> Color(0xFFDCEFE3)
        false -> Color(0xFFFFE2E0)
        null -> Sand
    }
    Column(
        Modifier
            .fillMaxWidth()
            .heightIn(min = 72.dp, max = 140.dp)
            .background(bg, RoundedCornerShape(10.dp))
            .padding(10.dp)
            .verticalScroll(rememberScrollState()),
    ) {
        if (state.compiling) {
            LinearProgressIndicator(modifier = Modifier.fillMaxWidth(), color = Moss)
            Spacer(Modifier.height(6.dp))
        }
        Text(
            state.compileLog,
            fontFamily = FontFamily.Monospace,
            fontSize = 12.sp,
            color = Ink,
        )
    }
}

@Composable
private fun BuildScreen(
    state: AppUiState,
    onCompileModeChange: (CompileMode) -> Unit,
    onServerUrlChange: (String) -> Unit,
    onAutoCompileChange: (Boolean) -> Unit,
    onAutoFixChange: (Boolean) -> Unit,
    onCheckServer: () -> Unit,
    onCompileNow: () -> Unit,
) {
    Column(
        Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(16.dp),
    ) {
        Text(
            "Compilazione",
            style = MaterialTheme.typography.headlineSmall,
            fontWeight = FontWeight.SemiBold,
            color = Ink,
        )
        Text(
            "Di default gira DENTRO l'app (Python e JavaScript).",
            color = Smoke,
        )
        Spacer(Modifier.height(12.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            FilterChip(
                selected = state.compileMode == CompileMode.LOCAL,
                onClick = { onCompileModeChange(CompileMode.LOCAL) },
                label = { Text("Nell'app") },
            )
            FilterChip(
                selected = state.compileMode == CompileMode.REMOTE,
                onClick = { onCompileModeChange(CompileMode.REMOTE) },
                label = { Text("PC (opzionale)") },
            )
        }
        Spacer(Modifier.height(10.dp))
        Text(
            if (state.localRuntimeReady) "Runtime app pronto" else "Runtime app in avvio…",
            color = if (state.localRuntimeReady) Moss else Smoke,
            fontWeight = FontWeight.Medium,
        )
        Spacer(Modifier.height(12.dp))
        if (state.compileMode == CompileMode.REMOTE) {
            Text("URL server PC", fontWeight = FontWeight.Medium, color = Ink)
            Spacer(Modifier.height(6.dp))
            BasicTextField(
                value = state.compileServerUrl,
                onValueChange = onServerUrlChange,
                textStyle = TextStyle(color = Ink, fontFamily = FontFamily.Monospace, fontSize = 14.sp),
                modifier = Modifier
                    .fillMaxWidth()
                    .background(Sand, RoundedCornerShape(10.dp))
                    .padding(12.dp),
            )
            Spacer(Modifier.height(8.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedButton(onClick = onCheckServer) {
                    Icon(Icons.Default.Refresh, contentDescription = null)
                    Spacer(Modifier.width(6.dp))
                    Text("Test PC")
                }
                Button(
                    onClick = onCompileNow,
                    colors = ButtonDefaults.buttonColors(containerColor = Moss),
                ) {
                    Text("Compila ora")
                }
            }
            Spacer(Modifier.height(8.dp))
            Text(
                when (state.serverOnline) {
                    true -> "Server online · ${state.serverTools}"
                    false -> "Server offline · ${state.serverTools}"
                    null -> "Stato server sconosciuto"
                },
                color = when (state.serverOnline) {
                    true -> Moss
                    false -> Color(0xFF8A1F17)
                    null -> Smoke
                },
            )
        } else {
            Button(
                onClick = onCompileNow,
                colors = ButtonDefaults.buttonColors(containerColor = Moss),
            ) {
                Text("Esegui ora nell'app")
            }
            Spacer(Modifier.height(8.dp))
            Text(
                "Supportati nell'app: Python, JavaScript.\nJava/Kotlin: usa modalità PC.",
                color = Smoke,
                fontSize = 13.sp,
            )
        }
        Spacer(Modifier.height(16.dp))
        Row(
            Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(Modifier.weight(1f)) {
                Text("Auto-compile", fontWeight = FontWeight.Medium, color = Ink)
                Text("Esegue a ogni modifica del codice", color = Smoke, fontSize = 13.sp)
            }
            Switch(checked = state.autoCompile, onCheckedChange = onAutoCompileChange)
        }
        Spacer(Modifier.height(8.dp))
        Row(
            Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(Modifier.weight(1f)) {
                Text("Auto-fix AI", fontWeight = FontWeight.Medium, color = Ink)
                Text("Se fallisce, chiede all'AI di correggere", color = Smoke, fontSize = 13.sp)
            }
            Switch(checked = state.autoFixOnError, onCheckedChange = onAutoFixChange)
        }
        Spacer(Modifier.height(16.dp))
        Text("Output", fontWeight = FontWeight.Medium, color = Ink)
        Spacer(Modifier.height(6.dp))
        CompileOutputBox(state)
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
                "AI + esecuzione codice (Python/JS) sul telefono.",
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
