package com.example.exam_guard

import android.Manifest
import android.annotation.SuppressLint
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.location.LocationManager
import android.net.wifi.WifiManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Wi-Fi access point scans on MethodChannel "exam_guard/wifi".
 *
 *  - status → {sdkInt, wifiEnabled, scanAlwaysAvailable, locationEnabled,
 *    hasPermission}
 *  - scan → {started, results}: requests a scan and answers when
 *    SCAN_RESULTS_AVAILABLE arrives (or after [SCAN_TIMEOUT_MS]). When
 *    Android throttles the request (4 scans / 2 min in the foreground),
 *    `started` is false and the cached results are returned.
 *  - getScanResults → cached results
 * Each result: {ssid, bssid, level, frequency, capabilities}. A
 * SecurityException becomes error code "permissionDenied".
 */
class WifiScanner(private val context: Context) : MethodChannel.MethodCallHandler {
    private val main = Handler(Looper.getMainLooper())
    private var pending: Pending? = null

    private class Pending(val receiver: BroadcastReceiver, val timeout: Runnable, val results: MutableList<MethodChannel.Result>)

    private val wifi: WifiManager?
        get() = context.applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "status" -> result.success(status())
            "scan" -> scan(result)
            "getScanResults" -> guarded(result) { result.success(readResults()) }
            else -> result.notImplemented()
        }
    }

    /** Drops a pending scan (activity destroyed). */
    fun dispose() {
        val p = pending ?: return
        pending = null
        main.removeCallbacks(p.timeout)
        unregister(p.receiver)
        p.results.forEach { it.success(mapOf("started" to false, "results" to emptyList<Any>())) }
    }

    private fun status(): Map<String, Any?> {
        val wm = wifi
        @Suppress("DEPRECATION")
        val scanAlways = try { wm?.isScanAlwaysAvailable ?: false } catch (e: Exception) { false }
        return mapOf(
            "sdkInt" to Build.VERSION.SDK_INT,
            "wifiEnabled" to (wm?.isWifiEnabled ?: false),
            "scanAlwaysAvailable" to scanAlways,
            "locationEnabled" to locationEnabled(),
            "hasPermission" to hasPermission(),
            "supported" to (wm != null),
        )
    }

    private fun scan(result: MethodChannel.Result) {
        val wm = wifi ?: return result.success(mapOf("started" to false, "results" to emptyList<Any>()))
        // A scan is already in flight: answer together with it.
        pending?.let { it.results.add(result); return }
        guarded(result) {
            @Suppress("DEPRECATION")
            val started = wm.startScan()
            if (!started) {
                result.success(mapOf("started" to false, "results" to readResults()))
                return@guarded
            }
            val receiver = object : BroadcastReceiver() {
                override fun onReceive(ctx: Context, intent: Intent) = complete(true)
            }
            val timeout = Runnable { complete(true) }
            pending = Pending(receiver, timeout, mutableListOf(result))
            val filter = IntentFilter(WifiManager.SCAN_RESULTS_AVAILABLE_ACTION)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                context.registerReceiver(receiver, filter, Context.RECEIVER_EXPORTED)
            } else {
                context.registerReceiver(receiver, filter)
            }
            main.postDelayed(timeout, SCAN_TIMEOUT_MS)
        }
    }

    private fun complete(started: Boolean) {
        val p = pending ?: return
        pending = null
        main.removeCallbacks(p.timeout)
        unregister(p.receiver)
        for (r in p.results) {
            guarded(r) { r.success(mapOf("started" to started, "results" to readResults())) }
        }
    }

    private fun unregister(receiver: BroadcastReceiver) {
        try {
            context.unregisterReceiver(receiver)
        } catch (e: IllegalArgumentException) {
            Log.w(TAG, "receiver already unregistered", e)
        }
    }

    @SuppressLint("MissingPermission")
    private fun readResults(): List<Map<String, Any?>> {
        val wm = wifi ?: return emptyList()
        return wm.scanResults.orEmpty().map {
            @Suppress("DEPRECATION")
            mapOf(
                "ssid" to it.SSID,
                "bssid" to it.BSSID,
                "level" to it.level,
                "frequency" to it.frequency,
                "capabilities" to it.capabilities,
            )
        }
    }

    private inline fun guarded(result: MethodChannel.Result, block: () -> Unit) {
        try {
            block()
        } catch (e: SecurityException) {
            Log.w(TAG, "Wi-Fi scan denied", e)
            result.error("permissionDenied", e.message, null)
        } catch (e: Exception) {
            Log.w(TAG, "Wi-Fi scan failed", e)
            result.error("failed", e.message, null)
        }
    }

    private fun hasPermission(): Boolean {
        val p = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            Manifest.permission.NEARBY_WIFI_DEVICES
        } else {
            Manifest.permission.ACCESS_FINE_LOCATION
        }
        return context.checkSelfPermission(p) == PackageManager.PERMISSION_GRANTED
    }

    private fun locationEnabled(): Boolean {
        val lm = context.getSystemService(Context.LOCATION_SERVICE) as? LocationManager ?: return false
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            lm.isLocationEnabled
        } else {
            @Suppress("DEPRECATION")
            lm.isProviderEnabled(LocationManager.GPS_PROVIDER) ||
                lm.isProviderEnabled(LocationManager.NETWORK_PROVIDER)
        }
    }

    companion object {
        private const val TAG = "WifiScanner"
        private const val SCAN_TIMEOUT_MS = 6000L
    }
}
