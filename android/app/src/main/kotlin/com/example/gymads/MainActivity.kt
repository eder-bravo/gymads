package com.example.gymads

import com.google.android.gms.common.ConnectionResult
import com.google.android.gms.common.GoogleApiAvailability
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.gymone/google_play_services",
        ).setMethodCallHandler { call, result ->
            if (call.method != "isAvailable") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val status = GoogleApiAvailability.getInstance()
                .isGooglePlayServicesAvailable(this)
            result.success(status == ConnectionResult.SUCCESS)
        }
    }
}
