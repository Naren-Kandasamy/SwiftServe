package com.crisisnet.guest_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.google.mediapipe.tasks.genai.llminference.LlmInference
import com.google.mediapipe.tasks.genai.llminference.LlmInferenceOptions
import java.io.File
import android.util.Log

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.crisisnet.guest_app/ai_bridge"
    private var gemmaInference: LlmInference? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "generateWithGemma" -> {
                    val prompt = call.argument<String>("prompt")
                    val modelPath = call.argument<String>("modelPath")
                    
                    if (prompt != null && modelPath != null) {
                        Thread {
                            try {
                                val response = runGemmaInference(prompt, modelPath)
                                runOnUiThread { result.success(response) }
                            } catch (e: Exception) {
                                runOnUiThread { result.error("GEMMA_ERROR", e.message, null) }
                            }
                        }.start()
                    } else {
                        result.error("INVALID_ARGS", "Prompt or model path is null", null)
                    }
                }
                "generateWithNano" -> {
                    // Logic for AICore / Gemini Nano
                    // On supported devices, this would connect to the system AICore service
                    // For this hackathon version, we return null to trigger Universal fallback
                    // but provide the bridge structure.
                    result.success(null) 
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private val gemmaLock = java.util.concurrent.locks.ReentrantLock()

    private fun runGemmaInference(prompt: String, modelPath: String): String {
        gemmaLock.lock()
        try {
            if (gemmaInference == null) {
                val file = File(modelPath)
                if (!file.exists()) {
                    throw Exception("Model file not found at $modelPath")
                }

                val options = LlmInferenceOptions.builder()
                    .setModelPath(modelPath)
                    .setMaxTokens(1024)
                    .setTopK(40)
                    .setTemperature(0.8f)
                    .build()
                
                gemmaInference = LlmInference.createFromOptions(context, options)
            }

            return gemmaInference?.generateResponse(prompt) ?: "No response from Gemma"
        } finally {
            gemmaLock.unlock()
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        gemmaInference?.close()
    }
}
