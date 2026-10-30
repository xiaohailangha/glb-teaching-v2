package com.local.snow.snow_speaks

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.os.Build
import android.Manifest
import android.content.pm.PackageManager

class MainActivity : FlutterActivity() {
    private var quality = "high"
    private var microphoneResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "glb/microphone")
            .setMethodCallHandler { call, result ->
                if (call.method != "requestPermission") {
                    result.notImplemented()
                } else if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED) {
                    result.success(true)
                } else if (microphoneResult != null) {
                    result.success(false)
                } else {
                    microphoneResult = result
                    requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), 5296)
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "glb/rendering")
            .setMethodCallHandler { call, result ->
                if (call.method == "setProfile") {
                    val requested = call.argument<String>("quality")
                    if (requested !in listOf("high", "medium", "low")) {
                        result.error("invalid_profile", "Unknown rendering profile", null)
                    } else {
                        quality = requested!!
                        requestRefreshRate()
                        result.success(null)
                    }
                } else result.notImplemented()
            }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 5296) {
            microphoneResult?.success(grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED)
            microphoneResult = null
        }
    }

    override fun onResume() {
        super.onResume()
        requestRefreshRate()
    }

    @Suppress("DEPRECATION")
    private fun requestRefreshRate() {
        val currentDisplay = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) display else windowManager.defaultDisplay
        currentDisplay ?: return
        val currentMode = currentDisplay.mode
        val limit = if (quality == "high") 120f else 60f
        val requested = currentDisplay.supportedModes
            .filter { it.physicalWidth == currentMode.physicalWidth && it.physicalHeight == currentMode.physicalHeight }
            .map { it.refreshRate }
            .filter { it <= limit + .5f }
            .maxOrNull() ?: minOf(currentDisplay.refreshRate, limit)
        // A preference, never a promise: power saving and thermal policy win.
        // Do not force a display-mode ID or change the screen resolution.
        window.attributes = window.attributes.apply { preferredRefreshRate = requested }
    }
}
