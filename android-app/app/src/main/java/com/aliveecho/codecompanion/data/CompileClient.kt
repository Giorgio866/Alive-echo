package com.aliveecho.codecompanion.data

import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import java.util.concurrent.TimeUnit

data class CompileResult(
    val ok: Boolean,
    val exitCode: Int,
    val stdout: String,
    val stderr: String,
    val durationMs: Int,
    val language: String?,
    val phase: String?,
    val errorMessage: String? = null,
) {
    val combinedOutput: String
        get() = buildString {
            if (stdout.isNotBlank()) append(stdout.trim()).append('\n')
            if (stderr.isNotBlank()) append(stderr.trim())
        }.trim()
}

class CompileClient(
    private val client: OkHttpClient = OkHttpClient.Builder()
        .connectTimeout(5, TimeUnit.SECONDS)
        .readTimeout(45, TimeUnit.SECONDS)
        .writeTimeout(20, TimeUnit.SECONDS)
        .build(),
) {
    fun health(baseUrl: String): Pair<Boolean, String> {
        val url = baseUrl.trimEnd('/') + "/health"
        val request = Request.Builder().url(url).get().build()
        return try {
            client.newCall(request).execute().use { response ->
                val body = response.body?.string().orEmpty()
                if (!response.isSuccessful) {
                    false to "HTTP ${response.code}"
                } else {
                    val json = JSONObject(body)
                    val tools = json.optJSONObject("tools")
                    val summary = if (tools != null) {
                        tools.keys().asSequence().joinToString(", ") { key ->
                            "$key=${tools.optBoolean(key)}"
                        }
                    } else {
                        "ok"
                    }
                    true to summary
                }
            }
        } catch (e: Exception) {
            false to (e.message ?: "Connessione fallita")
        }
    }

    fun compile(baseUrl: String, language: String, code: String): CompileResult {
        val url = baseUrl.trimEnd('/') + "/compile"
        val payload = JSONObject()
            .put("language", language)
            .put("code", code)
            .toString()
        val request = Request.Builder()
            .url(url)
            .post(payload.toRequestBody("application/json; charset=utf-8".toMediaType()))
            .build()
        return try {
            client.newCall(request).execute().use { response ->
                val body = response.body?.string().orEmpty()
                if (body.isBlank()) {
                    return CompileResult(
                        ok = false,
                        exitCode = response.code,
                        stdout = "",
                        stderr = "Risposta vuota dal server",
                        durationMs = 0,
                        language = language,
                        phase = "http",
                        errorMessage = "HTTP ${response.code}",
                    )
                }
                val json = JSONObject(body)
                CompileResult(
                    ok = json.optBoolean("ok"),
                    exitCode = json.optInt("exitCode", 1),
                    stdout = json.optString("stdout"),
                    stderr = json.optString("stderr"),
                    durationMs = json.optInt("durationMs"),
                    language = json.optString("language", language),
                    phase = json.optString("phase", "run"),
                )
            }
        } catch (e: Exception) {
            CompileResult(
                ok = false,
                exitCode = -1,
                stdout = "",
                stderr = e.message ?: "Errore di rete",
                durationMs = 0,
                language = language,
                phase = "network",
                errorMessage = e.message,
            )
        }
    }
}
