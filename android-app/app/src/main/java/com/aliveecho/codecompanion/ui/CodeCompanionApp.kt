package com.aliveecho.codecompanion.ui

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
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
import androidx.compose.material.icons.filled.Image
import androidx.compose.material.icons.filled.Memory
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Search
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
import androidx.compose.runtime.LaunchedEffect
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
import androidx.compose.runtime.remember
import androidx.compose.ui.graphics.asImageBitmap
import android.graphics.BitmapFactory
import com.aliveecho.codecompanion.AppUiState
import com.aliveecho.codecompanion.ChatMessage
import com.aliveecho.codecompanion.CompileMode
import com.aliveecho.codecompanion.HfModel
import com.aliveecho.codecompanion.ModelCatalog
import com.aliveecho.codecompanion.ModelKind
import com.aliveecho.codecompanion.data.HfSearchHit

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
    onHfQueryChange: (String) -> Unit,
    onHfTokenChange: (String) -> Unit,
    onSearchHf: () -> Unit,
    onPickHfRepo: (HfSearchHit) -> Unit,
    onAddCustom: (String, String) -> Unit,
    onImagePromptChange: (String) -> Unit,
    onGenerateImage: () -> Unit,
    onRefreshLocal: () -> Unit,
    onLocalQueryChange: (String) -> Unit,
    onImportUri: (android.net.Uri) -> Unit,
) {
    var tab by rememberSaveable { mutableIntStateOf(0) }
    LaunchedEffect(tab) {
        if (tab == 4) onRefreshLocal()
    }

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
                            state.imageDownloading ->
                                "Download img ${(state.imageProgress * 100).toInt()}%"
                            state.generatingImage -> "Immagine…"
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
                    icon = { Icon(Icons.Default.Image, contentDescription = null) },
                    label = { Text("Immagini") },
                )
                NavigationBarItem(
                    selected = tab == 4,
                    onClick = { tab = 4 },
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
            if (state.imageDownloading) {
                Column(
                    Modifier
                        .fillMaxWidth()
                        .background(Moss.copy(alpha = 0.12f))
                        .padding(12.dp),
                ) {
                    Text(
                        "Download modello immagini",
                        fontWeight = FontWeight.SemiBold,
                        color = Ink,
                    )
                    Spacer(Modifier.height(6.dp))
                    if (state.imageProgress <= 0.02f) {
                        LinearProgressIndicator(
                            modifier = Modifier.fillMaxWidth(),
                            color = Moss,
                        )
                    } else {
                        LinearProgressIndicator(
                            progress = { state.imageProgress.coerceIn(0.02f, 1f) },
                            modifier = Modifier.fillMaxWidth(),
                            color = Moss,
                        )
                    }
                    Spacer(Modifier.height(4.dp))
                    Text(
                        "${(state.imageProgress * 100).toInt()}%  ${state.imageDownloadLabel}",
                        color = Ink,
                        fontSize = 13.sp,
                    )
                    Text(
                        state.imageStatus,
                        color = Smoke,
                        fontSize = 12.sp,
                        maxLines = 2,
                    )
                }
            }
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
                3 -> ImageScreen(
                    state = state,
                    onPromptChange = onImagePromptChange,
                    onGenerate = onGenerateImage,
                    onGoModels = { tab = 4 },
                )
                else -> ModelsScreen(
                    state = state,
                    onDownload = onDownload,
                    onLoad = onLoad,
                    onHfQueryChange = onHfQueryChange,
                    onHfTokenChange = onHfTokenChange,
                    onSearchHf = onSearchHf,
                    onPickHfRepo = onPickHfRepo,
                    onAddCustom = onAddCustom,
                    onRefreshLocal = onRefreshLocal,
                    onLocalQueryChange = onLocalQueryChange,
                    onImportUri = onImportUri,
                )
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
private fun ImageScreen(
    state: AppUiState,
    onPromptChange: (String) -> Unit,
    onGenerate: () -> Unit,
    onGoModels: () -> Unit,
) {
    val bitmap = remember(state.lastImagePath) {
        state.lastImagePath?.let { BitmapFactory.decodeFile(it)?.asImageBitmap() }
    }
    Column(
        Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(16.dp),
    ) {
        Text(
            "Immagini uncensored",
            style = MaterialTheme.typography.headlineSmall,
            fontWeight = FontWeight.SemiBold,
            color = Ink,
        )
        Text(
            "Sul telefono Janus non entra in RAM (file da 1 GB). Premi Genera: è veloce e senza filtri extra.",
            color = Smoke,
        )
        Spacer(Modifier.height(8.dp))
        Text(
            state.imageStatus,
            color = Moss,
            fontWeight = FontWeight.Medium,
        )
        Text(
            if (state.loadedImageModel == null || state.loadedImageModel == "veloce") {
                "Motore veloce · nessun download"
            } else {
                state.loadedImageModel.orEmpty()
            },
            color = Smoke,
            fontSize = 12.sp,
            fontFamily = FontFamily.Monospace,
        )
        if (state.imageDownloading) {
            Spacer(Modifier.height(10.dp))
            if (state.imageProgress <= 0.02f) {
                LinearProgressIndicator(modifier = Modifier.fillMaxWidth(), color = Moss)
            } else {
                LinearProgressIndicator(
                    progress = { state.imageProgress.coerceIn(0.02f, 1f) },
                    modifier = Modifier.fillMaxWidth(),
                    color = Moss,
                )
            }
            Text(
                "${(state.imageProgress * 100).toInt()}%  ${state.imageDownloadLabel}",
                color = Ink,
                fontSize = 13.sp,
            )
        }
        Spacer(Modifier.height(12.dp))
        BasicTextField(
            value = state.imagePrompt,
            onValueChange = onPromptChange,
            textStyle = TextStyle(color = Ink, fontSize = 16.sp),
            modifier = Modifier
                .fillMaxWidth()
                .heightIn(min = 90.dp)
                .background(Sand, RoundedCornerShape(12.dp))
                .padding(14.dp),
            decorationBox = { inner ->
                if (state.imagePrompt.isEmpty()) {
                    Text("Prompt, es. a portrait of an adult woman, photorealistic…", color = Smoke)
                }
                inner()
            },
        )
        Spacer(Modifier.height(10.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Button(
                onClick = onGenerate,
                enabled = !state.generatingImage && state.imagePrompt.isNotBlank(),
                colors = ButtonDefaults.buttonColors(containerColor = Moss),
                modifier = Modifier.weight(1f),
            ) {
                Text(if (state.generatingImage) "Genero…" else "Genera")
            }
            OutlinedButton(onClick = onGoModels, modifier = Modifier.weight(1f)) {
                Text("Scegli modello")
            }
        }
        if (state.generatingImage) {
            Spacer(Modifier.height(8.dp))
            LinearProgressIndicator(modifier = Modifier.fillMaxWidth(), color = Moss)
        }
        Spacer(Modifier.height(12.dp))
        if (bitmap != null) {
            Image(
                bitmap = bitmap,
                contentDescription = "Immagine generata",
                modifier = Modifier
                    .fillMaxWidth()
                    .background(Ink, RoundedCornerShape(12.dp)),
            )
        } else {
            Text("Nessuna immagine ancora. Scrivi un prompt e premi Genera.", color = Smoke)
        }
    }
}

@Composable
private fun ModelsScreen(
    state: AppUiState,
    onDownload: (HfModel) -> Unit,
    onLoad: (HfModel) -> Unit,
    onHfQueryChange: (String) -> Unit,
    onHfTokenChange: (String) -> Unit,
    onSearchHf: () -> Unit,
    onPickHfRepo: (HfSearchHit) -> Unit,
    onAddCustom: (String, String) -> Unit,
    onRefreshLocal: () -> Unit,
    onLocalQueryChange: (String) -> Unit,
    onImportUri: (android.net.Uri) -> Unit,
) {
    val catalogIds = state.downloadedModels.map { it.repo + "/" + it.file }.toSet()
    val picker = androidx.activity.compose.rememberLauncherForActivityResult(
        contract = androidx.activity.result.contract.ActivityResultContracts.OpenDocument(),
    ) { uri ->
        if (uri != null) onImportUri(uri)
    }
    val visibleLocal = state.downloadedModels.filter { model ->
        val q = state.localQuery.trim()
        q.isEmpty() ||
            model.name.contains(q, ignoreCase = true) ||
            model.file.contains(q, ignoreCase = true) ||
            model.repo.contains(q, ignoreCase = true)
    }
    LazyColumn(
        Modifier
            .fillMaxSize()
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        item {
            Text(
                "Modelli sul telefono",
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.SemiBold,
                color = Ink,
            )
            Text(
                if (state.downloadedModels.isEmpty()) {
                    "Nessun file scaricato. Scarica dal catalogo o da Hugging Face."
                } else {
                    "Tocca un modello già scaricato per usarlo."
                },
                color = Smoke,
            )
            TextButton(onClick = onRefreshLocal) { Text("Aggiorna lista") }
            Spacer(Modifier.height(8.dp))
            Button(
                onClick = { picker.launch(arrayOf("*/*")) },
                colors = ButtonDefaults.buttonColors(containerColor = MossDark),
                modifier = Modifier.fillMaxWidth(),
            ) {
                Icon(Icons.Default.Search, contentDescription = null)
                Spacer(Modifier.width(8.dp))
                Text("Cerca modelli sul telefono")
            }
            Spacer(Modifier.height(8.dp))
            BasicTextField(
                value = state.localQuery,
                onValueChange = onLocalQueryChange,
                textStyle = TextStyle(color = Ink, fontSize = 16.sp),
                modifier = Modifier
                    .fillMaxWidth()
                    .background(Sand, RoundedCornerShape(10.dp))
                    .padding(12.dp),
                decorationBox = { inner ->
                    if (state.localQuery.isEmpty()) {
                        Text("Filtra i modelli già sul telefono…", color = Smoke)
                    }
                    inner()
                },
            )
            Text(
                if (state.engineReady) "Motore chat pronto" else "Motore chat in avvio…",
                color = if (state.engineReady) Moss else Smoke,
            )
            Text(
                state.loadedModelLabel ?: "Nessun modello chat caricato",
                color = Smoke,
                fontSize = 12.sp,
            )
        }
        items(visibleLocal, key = { it.id }) { model ->
            ModelCard(
                model = model,
                selected = state.selectedModelId == model.id ||
                    state.loadedModelLabel?.contains(model.file) == true ||
                    state.loadedImageModel == model.repo,
                downloaded = true,
                progress = cardProgress(state, model),
                progressLabel = cardProgressLabel(state, model),
                busy = state.busy,
                engineReady = if (model.kind == ModelKind.IMAGE) state.imageEngineReady else state.engineReady,
                downloading = state.imageDownloading && state.selectedModelId == model.id,
                useNow = true,
                onDownload = { onDownload(model) },
                onLoad = { onLoad(model) },
            )
        }
        item {
            Text(
                "Cerca su Hugging Face",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
                color = Ink,
            )
            Text(
                "Cerca qualsiasi repo. GGUF = chat. Janus/SD ONNX = immagini.",
                color = Smoke,
            )
            Spacer(Modifier.height(8.dp))
            BasicTextField(
                value = state.hfQuery,
                onValueChange = onHfQueryChange,
                textStyle = TextStyle(color = Ink, fontSize = 16.sp),
                modifier = Modifier
                    .fillMaxWidth()
                    .background(Sand, RoundedCornerShape(10.dp))
                    .padding(12.dp),
            )
            Spacer(Modifier.height(8.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Button(
                    onClick = onSearchHf,
                    enabled = !state.hfSearching,
                    colors = ButtonDefaults.buttonColors(containerColor = Moss),
                ) { Text(if (state.hfSearching) "Cerco…" else "Cerca su HF") }
            }
            Spacer(Modifier.height(6.dp))
            Row(
                Modifier.horizontalScroll(rememberScrollState()),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                listOf("uncensored gguf", "dolphin gguf", "janus onnx", "stable diffusion onnx").forEach { q ->
                    FilterChip(selected = state.hfQuery == q, onClick = {
                        onHfQueryChange(q)
                    }, label = { Text(q) })
                }
            }
            Spacer(Modifier.height(8.dp))
            Text("Token HF (opzionale, per repo gated)", color = Smoke, fontSize = 12.sp)
            BasicTextField(
                value = state.hfToken,
                onValueChange = onHfTokenChange,
                textStyle = TextStyle(color = Ink, fontFamily = FontFamily.Monospace, fontSize = 13.sp),
                modifier = Modifier
                    .fillMaxWidth()
                    .background(Sand, RoundedCornerShape(10.dp))
                    .padding(10.dp),
            )
            Spacer(Modifier.height(8.dp))
            Text(
                if (state.engineReady) "Motore chat pronto" else "Motore chat in avvio…",
                color = if (state.engineReady) Moss else Smoke,
            )
            Text(
                state.imageStatus,
                color = if (state.imageEngineReady) Moss else Smoke,
                fontSize = 12.sp,
            )
        }
        if (state.hfResults.isNotEmpty()) {
            item {
                Text("Risultati ricerca", fontWeight = FontWeight.SemiBold, color = Ink)
            }
            items(state.hfResults) { hit ->
                val tooBig = Regex("""(?:[2-9][0-9]|[1-9][0-9]{2,})B""", RegexOption.IGNORE_CASE)
                    .containsMatchIn(hit.repoId)
                Column(
                    Modifier
                        .fillMaxWidth()
                        .background(Sand, RoundedCornerShape(12.dp))
                        .clickable { onPickHfRepo(hit) }
                        .padding(12.dp),
                ) {
                    Text(hit.repoId, fontWeight = FontWeight.Medium, color = Ink)
                    Text(
                        hit.pipelineTag + if (hit.gated) " · gated" else "",
                        color = Smoke,
                        fontSize = 12.sp,
                    )
                    if (tooBig) {
                        Text(
                            "Troppo grande per il telefono (usa 1B–3B).",
                            color = Color(0xFF8A1F17),
                            fontSize = 12.sp,
                        )
                    }
                    Spacer(Modifier.height(6.dp))
                    OutlinedButton(onClick = { onPickHfRepo(hit) }) {
                        Text("Usa questo repo")
                    }
                }
            }
        }
        if (state.hfFiles.isNotEmpty()) {
            item {
                Text("File GGUF del repo (tocca per aggiungere)", fontWeight = FontWeight.Medium, color = Ink)
            }
            items(state.hfFiles.take(12)) { file ->
                TextButton(onClick = {
                    val repo = state.selectedHfRepo ?: return@TextButton
                    onAddCustom(repo, file)
                }) {
                    Text(file, fontFamily = FontFamily.Monospace, fontSize = 12.sp, color = Ink)
                }
            }
        }
        item {
            Text("I tuoi modelli", fontWeight = FontWeight.SemiBold, color = Ink)
        }
        items(state.customModels.filter { (it.repo + "/" + it.file) !in catalogIds }) { model ->
            ModelCard(
                model = model,
                selected = state.selectedModelId == model.id,
                downloaded = model.id in state.downloadedIds,
                progress = cardProgress(state, model),
                progressLabel = cardProgressLabel(state, model),
                busy = state.busy,
                engineReady = if (model.kind == ModelKind.IMAGE) state.imageEngineReady else state.engineReady,
                downloading = state.imageDownloading && state.selectedModelId == model.id,
                onDownload = { onDownload(model) },
                onLoad = { onLoad(model) },
            )
        }
        item {
            Text("Catalogo", fontWeight = FontWeight.SemiBold, color = Ink)
        }
        items(ModelCatalog.models.filter { (it.repo + "/" + it.file) !in catalogIds }) { model ->
            ModelCard(
                model = model,
                selected = state.selectedModelId == model.id,
                downloaded = model.id in state.downloadedIds,
                progress = cardProgress(state, model),
                progressLabel = cardProgressLabel(state, model),
                busy = state.busy,
                engineReady = if (model.kind == ModelKind.IMAGE) state.imageEngineReady else state.engineReady,
                downloading = state.imageDownloading && state.selectedModelId == model.id,
                onDownload = { onDownload(model) },
                onLoad = { onLoad(model) },
            )
        }
    }
}

private fun cardProgress(state: AppUiState, model: HfModel): Float? {
    if (model.kind == ModelKind.IMAGE && state.imageDownloading && state.selectedModelId == model.id) {
        return state.imageProgress.coerceAtLeast(0.01f)
    }
    return state.downloadProgress[model.id]
}

private fun cardProgressLabel(state: AppUiState, model: HfModel): String? {
    if (model.kind == ModelKind.IMAGE && state.imageDownloading && state.selectedModelId == model.id) {
        return state.imageDownloadLabel.ifBlank { state.imageStatus }
    }
    val p = state.downloadProgress[model.id]
    return if (p != null && p < 1f) "${(p * 100).toInt()}%" else null
}

@Composable
private fun ModelCard(
    model: HfModel,
    selected: Boolean,
    downloaded: Boolean,
    progress: Float?,
    @Suppress("UNUSED_PARAMETER") busy: Boolean,
    engineReady: Boolean,
    onDownload: () -> Unit,
    onLoad: () -> Unit,
    useNow: Boolean = false,
    progressLabel: String? = null,
    downloading: Boolean = false,
) {
    val isImage = model.kind == ModelKind.IMAGE
    val canStart = if (isImage) true else engineReady
    val showBar = downloading || (progress != null && progress < 1f)
    Column(
        Modifier
            .fillMaxWidth()
            .clickable(enabled = canStart && !downloading) { onLoad() }
            .background(if (selected) Moss.copy(alpha = 0.10f) else Sand, RoundedCornerShape(14.dp))
            .padding(14.dp),
    ) {
        Text(model.name, fontWeight = FontWeight.SemiBold, color = Ink)
        Text(
            model.sizeLabel + " · " + (if (isImage) "immagini" else "chat") + " · " + model.tags.joinToString(" · "),
            color = Smoke,
            fontSize = 12.sp,
        )
        Spacer(Modifier.height(6.dp))
        Text(model.description, color = Ink)
        Spacer(Modifier.height(4.dp))
        Text("${model.repo}/${model.file}", color = Smoke, fontSize = 11.sp, fontFamily = FontFamily.Monospace)
        if (showBar) {
            Spacer(Modifier.height(8.dp))
            val pct = progress ?: 0.01f
            if (pct <= 0.02f) {
                LinearProgressIndicator(modifier = Modifier.fillMaxWidth(), color = Moss)
            } else {
                LinearProgressIndicator(
                    progress = { pct.coerceIn(0.02f, 1f) },
                    modifier = Modifier.fillMaxWidth(),
                    color = Moss,
                )
            }
            Text(
                buildString {
                    append("${(pct * 100).toInt()}%")
                    if (!progressLabel.isNullOrBlank()) {
                        append("  ")
                        append(progressLabel)
                    }
                },
                color = Ink,
                fontSize = 12.sp,
            )
        }
        Spacer(Modifier.height(10.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            if (!isImage && !useNow) {
                OutlinedButton(onClick = onDownload) {
                    Icon(Icons.Default.Download, contentDescription = null)
                    Spacer(Modifier.width(6.dp))
                    Text(if (downloaded) "Riscarica" else "Scarica")
                }
            }
            Button(
                onClick = onLoad,
                enabled = canStart && !downloading,
                colors = ButtonDefaults.buttonColors(containerColor = Moss),
            ) {
                Icon(if (isImage) Icons.Default.Download else Icons.Default.PlayArrow, contentDescription = null)
                Spacer(Modifier.width(6.dp))
                Text(
                    when {
                        downloading && isImage -> "Download…"
                        isImage && (downloaded || model.repo == "phone/fast") -> "Usa ora"
                        isImage -> "Scarica e carica"
                        useNow || downloaded -> "Usa ora"
                        selected -> "Ricarica"
                        else -> "Carica in AI"
                    },
                )
            }
        }
    }
}
