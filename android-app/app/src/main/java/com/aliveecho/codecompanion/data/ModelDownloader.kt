package com.aliveecho.codecompanion.data

import okhttp3.OkHttpClient
import okhttp3.Request
import java.io.File
import java.io.IOException
import java.util.concurrent.TimeUnit

class ModelDownloader(
    private val modelsDir: File,
    private val client: OkHttpClient = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(5, TimeUnit.MINUTES)
        .build(),
) {
    data class Progress(val bytesRead: Long, val totalBytes: Long)

    fun localFile(repo: String, file: String): File {
        val safeRepo = repo.replace('/', '_')
        val safeFile = file.replace('/', '_')
        return File(modelsDir, "${safeRepo}__$safeFile")
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
}
