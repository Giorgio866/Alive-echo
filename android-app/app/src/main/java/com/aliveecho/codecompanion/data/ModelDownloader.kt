package com.aliveecho.codecompanion.data

import android.net.Uri
import com.aliveecho.codecompanion.HfModel
import com.aliveecho.codecompanion.ModelKind
import okhttp3.OkHttpClient
import okhttp3.Request
import java.io.File
import java.io.IOException
import java.util.concurrent.TimeUnit

class ModelDownloader(
    private val modelsDir: File,
    private val client: OkHttpClient = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(15, TimeUnit.MINUTES)
        .writeTimeout(2, TimeUnit.MINUTES)
        .build(),
) {
    data class Progress(
        val bytesRead: Long,
        val totalBytes: Long,
        val currentFile: String = "",
        val fileIndex: Int = 0,
        val fileCount: Int = 0,
    )

    fun localFile(repo: String, file: String): File {
        val safeRepo = repo.replace('/', '_')
        val safeFile = file.replace('/', '_')
        return File(modelsDir, "${safeRepo}__$safeFile")
    }

    fun listDownloaded(known: List<HfModel>): List<HfModel> {
        modelsDir.mkdirs()
        val files = modelsDir.listFiles().orEmpty()
            .filter { it.isFile && it.length() > 1024 && !it.name.endsWith(".part") }
        val gguf = files.map { file ->
            val parsed = parseStoredName(file.name)
            val match = known.firstOrNull { localFile(it.repo, it.file).name == file.name }
            val mb = file.length().toDouble() / (1024.0 * 1024.0)
            val size = if (mb >= 900) String.format("%.1f GB", mb / 1024.0) else String.format("%.0f MB", mb)
            match?.copy(
                sizeLabel = size,
                description = "Già sul telefono. Tocca Usa ora per caricarlo.",
                tags = (match.tags + "scaricato").distinct(),
            ) ?: HfModel(
                id = "local-" + file.name.hashCode(),
                name = parsed?.second?.substringAfterLast('/') ?: file.name,
                repo = parsed?.first ?: "local",
                file = parsed?.second ?: file.name,
                sizeLabel = size,
                description = "Già sul telefono. Tocca Usa ora per caricarlo.",
                tags = listOf("scaricato"),
                kind = ModelKind.LLM,
            )
        }
        val images = listDownloadedImageModels(known)
        return (gguf + images).sortedBy { it.name.lowercase() }
    }

    fun imageRepoDir(repo: String): File = File(modelsDir, repo)

    fun isImageRepoReady(repo: String): Boolean {
        val dir = imageRepoDir(repo)
        val marker = File(dir, ".complete")
        val config = File(dir, "config.json")
        val index = File(dir, "model_index.json")
        if (!dir.isDirectory) return false
        if (!config.exists() && !index.exists()) return false
        val hasOnnx = dir.walkTopDown().any { it.isFile && it.name.contains(".onnx") && it.length() > 1024 }
        return (marker.exists() || hasOnnx) && hasOnnx
    }

    private fun listDownloadedImageModels(known: List<HfModel>): List<HfModel> {
        val found = LinkedHashMap<String, HfModel>()
        known.filter { it.kind == ModelKind.IMAGE && isImageRepoReady(it.repo) }.forEach { model ->
            val bytes = imageRepoDir(model.repo).walkTopDown().filter { it.isFile }.sumOf { it.length() }
            found[model.repo] = model.copy(
                sizeLabel = formatSize(bytes),
                description = "Già sul telefono. Tocca Usa ora per caricarlo.",
                tags = (model.tags + "scaricato").distinct(),
            )
        }
        modelsDir.listFiles().orEmpty().filter { it.isDirectory }.forEach { ownerDir ->
            ownerDir.listFiles().orEmpty().filter { it.isDirectory }.forEach inner@{ nameDir ->
                val repo = ownerDir.name + "/" + nameDir.name
                if (repo in found) return@inner
                if (!isImageRepoReady(repo)) return@inner
                val bytes = nameDir.walkTopDown().filter { it.isFile }.sumOf { it.length() }
                found[repo] = HfModel(
                    id = "local-img-" + repo.hashCode(),
                    name = nameDir.name,
                    repo = repo,
                    file = "q4",
                    sizeLabel = formatSize(bytes),
                    description = "Già sul telefono. Tocca Usa ora per caricarlo.",
                    tags = listOf("immagini", "scaricato"),
                    kind = ModelKind.IMAGE,
                )
            }
        }
        return found.values.toList()
    }

    private fun formatSize(bytes: Long): String {
        val mb = bytes.toDouble() / (1024.0 * 1024.0)
        return if (mb >= 900) String.format("%.1f GB", mb / 1024.0) else String.format("%.0f MB", mb)
    }

    private fun parseStoredName(stored: String): Pair<String, String>? {
        val parts = stored.split("__", limit = 2)
        if (parts.size != 2) return null
        val slash = parts[0].indexOf('_')
        val repo = if (slash >= 0) {
            parts[0].substring(0, slash) + "/" + parts[0].substring(slash + 1)
        } else {
            parts[0]
        }
        return repo to parts[1]
    }

    fun isDownloaded(repo: String, file: String): Boolean {
        val f = localFile(repo, file)
        return f.exists() && f.length() > 0L
    }

    fun download(
        repo: String,
        file: String,
        onProgress: (Progress) -> Unit,
    ): File {
        modelsDir.mkdirs()
        val target = localFile(repo, file)
        if (target.exists() && target.length() > 0L) return target

        val url = "https://huggingface.co/$repo/resolve/main/$file"
        val request = Request.Builder().url(url).get().build()
        client.newCall(request).execute().use { response ->
            if (!response.isSuccessful) {
                throw IOException("Download fallito: HTTP ${response.code}")
            }
            val body = response.body ?: throw IOException("Risposta vuota")
            val total = body.contentLength()
            val tmp = File(target.absolutePath + ".part")
            body.byteStream().use { input ->
                tmp.outputStream().use { output ->
                    val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
                    var readTotal = 0L
                    while (true) {
                        val read = input.read(buffer)
                        if (read < 0) break
                        output.write(buffer, 0, read)
                        readTotal += read
                        onProgress(Progress(readTotal, total))
                    }
                }
            }
            if (!tmp.renameTo(target)) {
                tmp.copyTo(target, overwrite = true)
                tmp.delete()
            }
            return target
        }
    }

    fun downloadRepoFiles(
        repo: String,
        files: List<HfRepoFile>,
        token: String?,
        onProgress: (Progress) -> Unit,
    ): File {
        if (files.isEmpty()) throw IOException("Nessun file da scaricare per $repo")
        val root = imageRepoDir(repo)
        root.mkdirs()
        val totalKnown = files.sumOf { it.size.coerceAtLeast(0L) }
        var completed = 0L
        files.forEachIndexed { index, remote ->
            val target = File(root, remote.path)
            target.parentFile?.mkdirs()
            val already = target.exists() && target.length() > 0L &&
                (remote.size <= 0L || target.length() == remote.size)
            if (already) {
                completed += target.length()
                onProgress(
                    Progress(
                        bytesRead = completed,
                        totalBytes = totalKnown.coerceAtLeast(completed),
                        currentFile = remote.path,
                        fileIndex = index + 1,
                        fileCount = files.size,
                    ),
                )
                return@forEachIndexed
            }
            val url = resolveHfUrl(repo, remote.path)
            val builder = Request.Builder().url(url).get()
            if (!token.isNullOrBlank()) {
                builder.header("Authorization", "Bearer $token")
            }
            client.newCall(builder.build()).execute().use { response ->
                if (!response.isSuccessful) {
                    throw IOException("Download ${remote.path} fallito: HTTP ${response.code}")
                }
                val body = response.body ?: throw IOException("Risposta vuota per ${remote.path}")
                val contentLen = body.contentLength()
                val fileTotal = when {
                    remote.size > 0L -> remote.size
                    contentLen > 0L -> contentLen
                    else -> 0L
                }
                val tmp = File(target.absolutePath + ".part")
                body.byteStream().use { input ->
                    tmp.outputStream().use { output ->
                        val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
                        var readTotal = 0L
                        while (true) {
                            val read = input.read(buffer)
                            if (read < 0) break
                            output.write(buffer, 0, read)
                            readTotal += read
                            val overallTotal = if (totalKnown > 0L) {
                                totalKnown
                            } else {
                                completed + (if (fileTotal > 0L) fileTotal else readTotal)
                            }
                            onProgress(
                                Progress(
                                    bytesRead = completed + readTotal,
                                    totalBytes = overallTotal,
                                    currentFile = remote.path,
                                    fileIndex = index + 1,
                                    fileCount = files.size,
                                ),
                            )
                        }
                    }
                }
                if (tmp.length() < 32L) {
                    tmp.delete()
                    throw IOException("File troppo piccolo: ${remote.path}")
                }
                if (target.exists()) target.delete()
                if (!tmp.renameTo(target)) {
                    tmp.copyTo(target, overwrite = true)
                    tmp.delete()
                }
                completed += target.length()
            }
        }
        File(root, ".complete").writeText("ok")
        return root
    }

    private fun resolveHfUrl(repo: String, file: String): String {
        val encodedRepo = repo.split('/').joinToString("/") { Uri.encode(it) }
        val encodedFile = file.split('/').joinToString("/") { Uri.encode(it) }
        return "https://huggingface.co/$encodedRepo/resolve/main/$encodedFile"
    }

    fun importStream(
        displayName: String,
        input: java.io.InputStream,
        totalBytes: Long,
        onProgress: (Progress) -> Unit,
    ): File {
        modelsDir.mkdirs()
        val safe = displayName.replace('/', '_').ifBlank { "model.gguf" }
        val target = File(modelsDir, "phone__$safe")
        val tmp = File(target.absolutePath + ".part")
        input.use { src ->
            tmp.outputStream().use { output ->
                val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
                var readTotal = 0L
                while (true) {
                    val read = src.read(buffer)
                    if (read < 0) break
                    output.write(buffer, 0, read)
                    readTotal += read
                    onProgress(Progress(readTotal, totalBytes))
                }
            }
        }
        if (!tmp.renameTo(target)) {
            tmp.copyTo(target, overwrite = true)
            tmp.delete()
        }
        return target
    }
}
