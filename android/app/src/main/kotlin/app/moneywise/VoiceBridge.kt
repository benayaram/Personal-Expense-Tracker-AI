package app.moneywise

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.speech.tts.TextToSpeech
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

/** Explicit, foreground voice actions only; no background recorder or audio files. */
class VoiceBridge(private val activity: Activity, channel: MethodChannel) : RecognitionListener {
    private var recognizer: SpeechRecognizer? = null
    private var pending: MethodChannel.Result? = null
    private var tts: TextToSpeech? = null
    private var ttsReady = false
    private var session = 0
    private var speechEpoch = 0
    private val handler = Handler(Looper.getMainLooper())
    private val timeout = Runnable { finishError("TIMEOUT", "No speech received. Please try again.") }
    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "listen" -> {
                    if (pending != null) result.error("BUSY", "Voice input is already active", null)
                    else if (!SpeechRecognizer.isRecognitionAvailable(activity)) result.error("UNAVAILABLE", "Install or enable a speech recognition service, or type your question", null)
                    else {
                        pending = result
                        if (activity.checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED) start()
                        else activity.requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), 803)
                    }
                }
                "cancel" -> { finishError("CANCELLED", "Voice input cancelled"); result.success(null) }
                "stop" -> { speechEpoch++; tts?.stop(); result.success(null) }
                "speak" -> {
                    val text = call.argument<String>("text").orEmpty().take(12000)
                    if (text.isBlank()) result.error("EMPTY", "There is no answer to read", null)
                    else if (ttsReady) speak(text, result)
                    else if (tts != null) result.error("BUSY", "Speech engine is starting. Please try again", null)
                    else {
                        val epoch = speechEpoch
                        tts = TextToSpeech(activity) { status ->
                            if (status == TextToSpeech.SUCCESS) {
                                ttsReady = true
                                tts?.language = Locale.getDefault()
                                tts?.setSpeechRate(0.9f)
                                if (epoch == speechEpoch) speak(text, result)
                                else result.error("CANCELLED", "Speech output stopped", null)
                            } else { tts?.shutdown(); tts = null; result.error("UNAVAILABLE", "Text-to-speech is unavailable on this device", null) }
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
    fun permission(requestCode: Int, grantResults: IntArray): Boolean {
        if (requestCode != 803) return false
        if (pending == null) return true
        if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) start()
        else finishError("PERMISSION", "Microphone permission was denied. You can still type questions.")
        return true
    }
    private fun start() {
        try {
            val current = ++session
            recognizer?.destroy()
            recognizer = SpeechRecognizer.createSpeechRecognizer(activity).also { it.setRecognitionListener(object : RecognitionListener {
                override fun onResults(results: Bundle?) { if (current == session) this@VoiceBridge.onResults(results) }
                override fun onError(error: Int) { if (current == session) this@VoiceBridge.onError(error) }
                override fun onReadyForSpeech(params: Bundle?) {}
                override fun onBeginningOfSpeech() {}
                override fun onRmsChanged(rmsdB: Float) {}
                override fun onBufferReceived(buffer: ByteArray?) {}
                override fun onEndOfSpeech() {}
                override fun onPartialResults(partialResults: Bundle?) {}
                override fun onEvent(eventType: Int, params: Bundle?) {}
            }) }
            handler.postDelayed(timeout, 30000)
            recognizer?.startListening(Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                putExtra(RecognizerIntent.EXTRA_LANGUAGE, Locale.getDefault().toLanguageTag())
                putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true)
                putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
            })
        } catch (_: Exception) { finishError("UNAVAILABLE", "Could not start speech recognition. Type your question instead.") }
    }
    private fun speak(text: String, result: MethodChannel.Result) {
        // Android engines have a per-utterance limit. Queue bounded chunks in order.
        tts?.stop()
        val limit = (TextToSpeech.getMaxSpeechInputLength() - 100).coerceAtLeast(500)
        val chunks = text.chunked(limit)
        for ((index, chunk) in chunks.withIndex()) {
            if (tts?.speak(chunk, TextToSpeech.QUEUE_ADD, null, "moneywise-$index") == TextToSpeech.ERROR) {
                result.error("UNAVAILABLE", "Speech output failed; the text answer is still available", null); return
            }
        }
        result.success(null)
    }
    private fun finishError(code: String, message: String) {
        val result = pending; pending = null; session++
        handler.removeCallbacks(timeout)
        if (result != null) recognizer?.cancel()
        result?.error(code, message, null)
    }
    fun stop() { speechEpoch++; finishError("CANCELLED", "Voice input stopped"); tts?.stop() }
    fun destroy() { stop(); recognizer?.destroy(); recognizer = null; tts?.shutdown(); tts = null }
    override fun onResults(results: Bundle?) {
        val result = pending; pending = null; session++; handler.removeCallbacks(timeout)
        val text = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull().orEmpty()
        if (text.isBlank()) result?.error("EMPTY", "No speech was recognized. Please try again", null) else result?.success(text)
    }
    override fun onError(error: Int) { finishError("RECOGNITION", "Speech recognition stopped ($error). Check microphone access, speech service and connection, or type instead.") }
    override fun onReadyForSpeech(params: Bundle?) {}
    override fun onBeginningOfSpeech() {}
    override fun onRmsChanged(rmsdB: Float) {}
    override fun onBufferReceived(buffer: ByteArray?) {}
    override fun onEndOfSpeech() {}
    override fun onPartialResults(partialResults: Bundle?) {}
    override fun onEvent(eventType: Int, params: Bundle?) {}
}
