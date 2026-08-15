package com.aliveecho.codecompanion

object CodeExtractor {
    private val fenced = Regex(
        """```(?:([a-zA-Z0-9_+-]+)\n)?([\s\S]*?)```""",
    )

    fun extractBestCode(answer: String): Pair<String, String?>? {
        val blocks = fenced.findAll(answer).map { match ->
            val lang = match.groupValues[1].ifBlank { null }
            val code = match.groupValues[2].trim()
            lang to code
        }.filter { it.second.isNotBlank() }.toList()

        if (blocks.isEmpty()) return null

        val preferred = listOf("kotlin", "kt", "java", "python", "py", "javascript", "js")
        val best = blocks.firstOrNull { (lang, _) ->
            lang != null && preferred.any { it.equals(lang, ignoreCase = true) }
        } ?: blocks.maxByOrNull { it.second.length } ?: return null

        val normalizedLang = when (best.first?.lowercase()) {
            "kt", "kotlin" -> "kotlin"
            "java" -> "java"
            "py", "python" -> "python"
            "js", "javascript", "node" -> "javascript"
            else -> null
        }
        return best.second to normalizedLang
    }

    fun cleanReply(raw: String): String {
        var text = raw.trim()
        val cuts = listOf(
            "CODICE APERTO:",
            "STATO COMPILAZIONE:",
            "RICHIESTA:",
            "<|im_end|>",
            "<|im_start|>",
            "```linguaggio",
        )
        cuts.forEach { marker ->
            val at = text.indexOf(marker)
            if (at >= 0) {
                text = if (at < 8) text.substring(at + marker.length) else text.substring(0, at)
            }
        }
        return text.trim().ifBlank { raw.trim() }
    }
}
