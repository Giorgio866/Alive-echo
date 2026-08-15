package com.aliveecho.codecompanion.image

import android.graphics.BitmapFactory
import okhttp3.OkHttpClient
import okhttp3.Request
import java.io.File
import java.io.IOException
import java.net.URLEncoder
import java.util.concurrent.TimeUnit
import kotlin.random.Random

class PhoneImageClient(
    private val imagesDir: File,
    private val client: OkHttpClient = OkHttpClient.Builder()
        .connectTimeout(20, TimeUnit.SECONDS)
        .readTimeout(90, TimeUnit.SECONDS)
        .followRedirects(true)
        .followSslRedirects(true)
        .build(),
) {
    fun generate(prompt: String, onStatus: (String) -> Unit = {}): String {
        val text = prompt.trim()
        if (text.isEmpty()) throw IOException("Prompt vuoto")
        imagesDir.mkdirs()
        val encoded = URLEncoder.encode(text, "UTF-8").replace("+", "%20")
        val seed = Random.nextInt(0, 1_000_000)
        val urls = listOf(
            "https://image.pollinations.ai/prompt/$encoded?width=768&height=768&nologo=true&safe=false&enhance=false&model=turbo&seed=$seed",
            "https://image.pollinations.ai/prompt/$encoded?width=640&height=640&nologo=true&safe=false&model=flux&seed=$seed",
        )
        var lastError: Exception? = null
        for ((index, url) in urls.withIndex()) {
            onStatus(if (index == 0) "Generazione veloce…" else "Secondo tentativo…")
            try {
                return fetchImage(url)
            } catch (e: Exception) {
                lastError = e
            }
        }
        throw IOException(lastError?.message ?: "Generazione immagine fallita")
    }

    private fun fetchImage(url: String): String {
        val request = Request.Builder()
            .url(url)
            .header("User-Agent", "Mozilla/5.0 CodeCompanion/1.0")
            .header("Accept", "image/*,*/*")
            .get()
            .build()
        client.newCall(request).execute().use { response ->
            if (!response.isSuccessful) {
                throw IOException("Generazione fallita: HTTP ${response.code}")
            }
            val bytes = response.body?.bytes() ?: throw IOException("Immagine vuota")
            if (bytes.size < 128) throw IOException("Immagine non valida")
            BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
                ?: throw IOException("PNG/JPEG non decodificabile")
            val out = File(imagesDir, "img-${System.currentTimeMillis()}.png")
            out.writeBytes(bytes)
            return out.absolutePath
        }
    }
}
