package com.aliveecho.codecompanion

data class HfModel(
    val id: String,
    val name: String,
    val repo: String,
    val file: String,
    val sizeLabel: String,
    val description: String,
    val tags: List<String>,
)

object ModelCatalog {
    val models: List<HfModel> = listOf(
        HfModel(
            id = "tinyllama",
            name = "TinyLlama 1.1B Chat Q4",
            repo = "TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF",
            file = "tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf",
            sizeLabel = "~670 MB",
            description = "Piccolo e veloce. Ideale per provare l'app su telefoni medi.",
            tags = listOf("chat", "piccolo"),
        ),
        HfModel(
            id = "qwen25-coder-15b",
            name = "Qwen2.5 Coder 1.5B Instruct Q4",
            repo = "Qwen/Qwen2.5-Coder-1.5B-Instruct-GGUF",
            file = "qwen2.5-coder-1.5b-instruct-q4_k_m.gguf",
            sizeLabel = "~1.1 GB",
            description = "Specializzato in programmazione. Consigliato per coding.",
            tags = listOf("coding", "consigliato"),
        ),
        HfModel(
            id = "llama32-1b",
            name = "Llama 3.2 1B Instruct Q4",
            repo = "bartowski/Llama-3.2-1B-Instruct-GGUF",
            file = "Llama-3.2-1B-Instruct-Q4_K_M.gguf",
            sizeLabel = "~800 MB",
            description = "Piccolo ma capace. Buon compromesso su telefoni moderni.",
            tags = listOf("chat", "coding"),
        ),
        HfModel(
            id = "dolphin-phi",
            name = "Dolphin-2.6 Phi-2 Q4 (uncensored)",
            repo = "TheBloke/dolphin-2_6-phi-2-GGUF",
            file = "dolphin-2_6-phi-2.Q4_K_M.gguf",
            sizeLabel = "~1.6 GB",
            description = "Variante uncensored piccola, utile per assistenza codice senza filtri aggressivi.",
            tags = listOf("uncensored", "coding"),
        ),
        HfModel(
            id = "stories",
            name = "TinyStories 260K (test)",
            repo = "ggml-org/models",
            file = "tinyllamas/stories260K.gguf",
            sizeLabel = "~1 MB",
            description = "Solo per test del motore. Non serve per programmare.",
            tags = listOf("test"),
        ),
    )
}
