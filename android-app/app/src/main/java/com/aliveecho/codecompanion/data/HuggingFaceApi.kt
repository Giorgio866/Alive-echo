package com.aliveecho.codecompanion.data

import com.aliveecho.codecompanion.HfModel
import com.aliveecho.codecompanion.ModelKind
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONArray
import org.json.JSONObject
import java.net.URLEncoder
import java.util.concurrent.TimeUnit

data class HfSearchHit(
    val repoId: String,
    val pipelineTag: String,
    val likes: Int,
    val downloads: Int,
    val gated: Boolean,
)

class HuggingFaceApi(
    private val client: OkHttpClient = OkHttpClient.Builder()
        .connectTimeout(20, TimeUnit.SECONDS)
        .readTimeout(40, TimeUnit.SECONDS)
        .build(),
) {
    fun search(query: String, token: String? = null, limit: Int = 20): List<HfSearchHit> {
        val q = URLEncoder.encode(query.trim().ifBlank { "gguf" }, "UTF-8")
        val url = "https://huggingface.co/api/models?search=$q&limit=$limit&sort=downloads"
        val json = get(url, token)
        val arr = JSONArray(json)
        val out = ArrayList<HfSearchHit>(arr.length())
        for (i in 0 until arr.length()) {
            val obj = arr.getJSONObject(i)
            out += HfSearchHit(
                repoId = obj.optString("id"),
                pipelineTag = obj.optString("pipeline_tag", "unknown"),
                likes = obj.optInt("likes"),
                downloads = obj.optInt("downloads"),
                gated = obj.optBoolean("gated"),
            )
        }
        return out
    }

    fun listFiles(repo: String, token: String? = null): List<String> {
        val url = "https://huggingface.co/api/models/$repo"
        val obj = JSONObject(get(url, token))
        val siblings = obj.optJSONArray("siblings") ?: JSONArray()
        val files = ArrayList<String>()
        for (i in 0 until siblings.length()) {
            val name = siblings.getJSONObject(i).optString("rfilename")
            if (name.isNotBlank()) files += name
        }
        return files
    }

    fun toModelFromRepo(
        repo: String,
        file: String?,
        pipelineTag: String,
        files: List<String>,
    ): HfModel {
        val gguf = files.filter { it.endsWith(".gguf", ignoreCase = true) }
        val isImage = pipelineTag.contains("image") ||
            pipelineTag.contains("any-to-any") ||
            repo.contains("Janus", ignoreCase = true) ||
            files.any { it.startsWith("unet/") || it == "model_index.json" }
        val chosen = file
            ?: gguf.firstOrNull { it.contains("Q4_K_M", ignoreCase = true) }
            ?: gguf.firstOrNull { it.contains("q4", ignoreCase = true) }
            ?: gguf.firstOrNull()
            ?: if (isImage) "q4" else ""
        val kind = if (isImage && gguf.isEmpty()) ModelKind.IMAGE else ModelKind.LLM
        return HfModel(
            id = "hf-" + repo.replace('/', '_') + "-" + chosen.hashCode(),
            name = repo.substringAfterLast('/'),
            repo = repo,
            file = chosen,
            sizeLabel = if (kind == ModelKind.IMAGE) "repo HF" else "GGUF",
            description = "Da Hugging Face · $pipelineTag",
            tags = listOf(pipelineTag.ifBlank { "custom" }),
            kind = kind,
        )
    }

    private fun get(url: String, token: String?): String {
        val builder = Request.Builder().url(url).get()
        if (!token.isNullOrBlank()) {
            builder.header("Authorization", "Bearer $token")
        }
        client.newCall(builder.build()).execute().use { response ->
            val body = response.body?.string().orEmpty()
            if (!response.isSuccessful) {
                throw IllegalStateException("HF HTTP ${response.code}: ${body.take(180)}")
            }
            return body
        }
    }
}
