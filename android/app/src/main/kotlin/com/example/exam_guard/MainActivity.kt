package com.example.exam_guard

import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var classicBt: ClassicBtDiscovery? = null
    private var wifiScanner: WifiScanner? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        // Classic (BR/EDR) Bluetooth inquiry: one discovery per subscription.
        classicBt = ClassicBtDiscovery(applicationContext).also {
            EventChannel(messenger, "exam_guard/classic_bt").setStreamHandler(it)
        }
        // Wi-Fi access point scans.
        wifiScanner = WifiScanner(applicationContext).also {
            MethodChannel(messenger, "exam_guard/wifi").setMethodCallHandler(it)
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "exam_guard/system")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // BLE scans return nothing on Android while Location is off.
                    "openLocationSettings" -> {
                        try {
                            startActivity(
                                Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS)
                                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            )
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        // Don't leave an inquiry running (it slows BLE) or leak receivers.
        classicBt?.stop()
        wifiScanner?.dispose()
        super.onDestroy()
    }
}
