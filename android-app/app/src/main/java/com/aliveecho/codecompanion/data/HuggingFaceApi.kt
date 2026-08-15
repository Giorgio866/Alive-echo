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

data class HfRepoFile(
    val path: String,
    val size: Long,
)

class HuggingFaceApi(
    private val client: OkHttpClient = OkHttpClient.Builder()
        .connectTimeout(20, TimeUnit.SECONDS)
        .readTimeout(40, TimeUnit.SECONDS)
        .build(),
) {
    fun search(query: String, token: String? = null, limit: Int = 20): List<HfSearchHit> {
        val raw = query.trim().ifBlank { "gguf" }
        val q = URLEncoder.encode(raw, "UTF-8")
        val wantsImage = raw.contains("janus", true) ||
            raw.contains("onnx", true) ||
            raw.contains("diffusion", true) ||
            raw.contains("immagine", true)
        val filter = if (wantsImage) "" else "&filter=gguf"
        val url = "https://huggingface.co/api/models?search=$q$filter&limit=$limit&sort=downloads"
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

    fun listRepoTree(repo: String, token: String? = null): List<HfRepoFile> {
        val url = "https://huggingface.co/api/models/$repo/tree/main?recursive=1"
        return try {
            val json = get(url, token)
            val arr = JSONArray(json)
            val out = ArrayList<HfRepoFile>(arr.length())
            for (i in 0 until arr.length()) {
                val obj = arr.getJSONObject(i)
                val type = obj.optString("type")
                if (type == "directory") continue
                val path = obj.optString("path").ifBlank { obj.optString("rfilename") }
                if (path.isBlank()) continue
                val lfsSize = obj.optJSONObject("lfs")?.optLong("size") ?: 0L
                val size = if (lfsSize > 0L) lfsSize else obj.optLong("size")
                out += HfRepoFile(path, size)
            }
            out.ifEmpty { listFiles(repo, token).map { HfRepoFile(it, 0L) } }
        } catch (_: Exception) {
            listFiles(repo, token).map { HfRepoFile(it, 0L) }
        }
    }

    fun filesForImageDownload(files: List<HfRepoFile>, dtype: String): List<HfRepoFile> {
        val dt = dtype.trim().lowercase().ifBlank { "q4" }
        val skipExact = setOf("readme.md", "license", "license.md", ".gitattributes")
        val metaExt = setOf("json", "txt", "model", "jinja", "tiktoken", "vocab")
        val meta = files.filter { file ->
            val name = file.path.substringAfterLast('/').lowercase()
            if (name in skipExact || name.startsWith(".")) return@filter false
            if (name.endsWith(".md") || name.endsWith(".png") || name.endsWith(".jpg") ||
                name.endsWith(".jpeg") || name.endsWith(".gif") || name.endsWith(".webp")
            ) {
                return@filter false
            }
            val ext = name.substringAfterLast('.', "")
            ext in metaExt || name.contains("tokenizer") || name == "model_index.json"
        }
        val onnxAll = files.filter { it.path.contains(".onnx") }
        val onnx = when {
            dt == "cpu" || dt == "fp32" -> onnxAll.filter { pathMatchesCpu(it.path) }.ifEmpty { onnxAll }
            else -> onnxAll.filter { pathMatchesDtype(it.path, dt) }
                .ifEmpty { onnxAll.filter { it.path.contains("quantized", ignoreCase = true) } }
                .ifEmpty { onnxAll.filter { pathMatchesCpu(it.path) } }
                .ifEmpty { onnxAll }
        }
        val selected = (meta + onnx).distinctBy { it.path }
        val selectedPaths = selected.map { it.path }.toSet()
        val extras = files.filter { file ->
            file.path.endsWith(".onnx_data") &&
                file.path.removeSuffix("_data") in selectedPaths &&
                file.path !in selectedPaths
        }
        return selected + extras
    }

    private fun pathMatchesDtype(path: String, dtype: String): Boolean {
        val name = path.substringAfterLast('/').lowercase()
        if (dtype == "q4" && name.contains("q4f16")) return false
        if (dtype != "q4f16" && name.contains("q4f16")) return false
        val token = dtype.lowercase()
        return name.contains("_$token.") ||
            name.contains("_$token.onnx") ||
            name.contains("-$token.") ||
            Regex("""(^|[^a-z0-9])${Regex.escape(token)}([^a-z0-9]|$)""").containsMatchIn(name)
    }

    private fun pathMatchesCpu(path: String): Boolean {
        val n = path.lowercase()
        return !n.contains("_q4") &&
            !n.contains("_q8") &&
            !n.contains("q4f16") &&
            !n.contains("bnb") &&
            !n.contains("int8") &&
            !n.contains("uint8") &&
            !n.contains("fp16") &&
            !n.contains("quantized")
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
