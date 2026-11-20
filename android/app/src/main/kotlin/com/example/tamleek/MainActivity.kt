package com.example.tamleek

import android.content.ActivityNotFoundException
import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "tamleek/network_settings",
        ).setMethodCallHandler { call, result ->
            if (call.method != "openWifiSettings") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            try {
                startActivity(Intent(Settings.ACTION_WIFI_SETTINGS))
                result.success(null)
            } catch (error: ActivityNotFoundException) {
                result.error("settings_unavailable", error.message, null)
            }
        }
    }
}
