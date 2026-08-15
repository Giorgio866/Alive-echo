package com.aliveecho.codecompanion

enum class ModelKind {
    LLM,
    IMAGE,
}

data class HfModel(
    val id: String,
    val name: String,
    val repo: String,
    val file: String,
    val sizeLabel: String,
    val description: String,
    val tags: List<String>,
    val kind: ModelKind = ModelKind.LLM,
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
        HfModel(
            id = "janus-pro-1b",
            name = "Janus Pro 1B ONNX (immagini)",
            repo = "onnx-community/Janus-Pro-1B-ONNX",
            file = "q4",
            sizeLabel = "~3 GB (q4)",
            description = "Genera immagini DENTRO l'app dopo il download. Nessun filtro extra nell'app.",
            tags = listOf("immagini", "uncensored"),
            kind = ModelKind.IMAGE,
        ),
        HfModel(
            id = "janus-13b",
            name = "Janus 1.3B ONNX (immagini)",
            repo = "onnx-community/Janus-1.3B-ONNX",
            file = "q4",
            sizeLabel = "~1.2 GB (q4)",
            description = "Modello immagini un po' più grande. Nessun safety checker nell'app.",
            tags = listOf("immagini", "uncensored"),
            kind = ModelKind.IMAGE,
        ),
        HfModel(
            id = "sd21-onnx",
            name = "Stable Diffusion 2.1 ONNX CPU",
            repo = "aislamov/stable-diffusion-2-1-base-onnx",
            file = "cpu",
            sizeLabel = "~2+ GB",
            description = "Diffusione classica, più pesante. Nessun safety checker. Serve tanta RAM.",
            tags = listOf("immagini", "sd", "uncensored"),
            kind = ModelKind.IMAGE,
        ),
    )
}
