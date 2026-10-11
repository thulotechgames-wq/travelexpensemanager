package com.bishworajpoudel.travelexpensemanager

import android.net.Uri
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "expensetracker/receipt_text")
            .setMethodCallHandler { call, result ->
                val path = call.argument<String>("path")
                if (call.method != "recognize" || path == null) {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                recognize(path, result)
            }
    }

    /// On-device receipt text recognition with ML Kit (bundled model, works offline).
    /// Returns one entry per recognized line: text plus its box in image pixels (top-left origin).
    private fun recognize(path: String, result: MethodChannel.Result) {
        val image = try {
            InputImage.fromFilePath(this, Uri.fromFile(File(path)))
        } catch (e: Exception) {
            result.success(emptyList<Map<String, Any>>())
            return
        }
        TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
            .process(image)
            .addOnSuccessListener { text ->
                val lines = text.textBlocks.flatMap { block ->
                    block.lines.mapNotNull { line ->
                        val b = line.boundingBox ?: return@mapNotNull null
                        mapOf(
                            "text" to line.text,
                            "x" to b.left.toDouble(),
                            "y" to b.top.toDouble(),
                            "w" to b.width().toDouble(),
                            "h" to b.height().toDouble(),
                        )
                    }
                }
                result.success(lines)
            }
            .addOnFailureListener { result.success(emptyList<Map<String, Any>>()) }
    }
}
