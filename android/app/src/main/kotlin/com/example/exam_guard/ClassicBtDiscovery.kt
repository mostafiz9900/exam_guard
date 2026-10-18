package com.example.exam_guard

import android.Manifest
import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothClass
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import io.flutter.plugin.common.EventChannel

/**
 * One classic Bluetooth inquiry per EventChannel subscription.
 *
 * Dart listens on "exam_guard/classic_bt" to start a discovery (~12 s) and
 * cancels the subscription to stop it. Events:
 *  - {type: "found", address, name, rssi, majorDeviceClass, deviceClass}
 *    (BR/EDR or dual-mode devices only — BLE-only devices are skipped)
 *  - {type: "finished", reason: "done" | "adapterOff" | "unsupported" |
 *    "permissionDenied" | "failed"}
 * The stream is never errored, so a missing permission or a SecurityException
 * just ends the cycle.
 */
class ClassicBtDiscovery(private val context: Context) : EventChannel.StreamHandler {
    private var sink: EventChannel.EventSink? = null
    private var receiver: BroadcastReceiver? = null

    private val adapter: BluetoothAdapter?
        get() = (context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager)?.adapter

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        stop()
        sink = events
        val bt = adapter
        if (bt == null) return finish("unsupported")
        if (!hasPermissions()) return finish("permissionDenied")
        try {
            if (!bt.isEnabled) return finish("adapterOff")
            register()
            if (bt.isDiscovering) bt.cancelDiscovery()
            if (!bt.startDiscovery()) {
                // Usually Bluetooth turning off, or Location off on some OEMs.
                finish("failed")
            }
        } catch (e: SecurityException) {
            Log.w(TAG, "startDiscovery denied", e)
            finish("permissionDenied")
        } catch (e: Exception) {
            Log.w(TAG, "startDiscovery failed", e)
            finish("failed")
        }
    }

    override fun onCancel(arguments: Any?) {
        stop()
    }

    /** Cancels a running inquiry and unregisters the receiver. */
    @SuppressLint("MissingPermission")
    fun stop() {
        sink = null
        receiver?.let {
            try {
                context.unregisterReceiver(it)
            } catch (e: IllegalArgumentException) {
                Log.w(TAG, "receiver already unregistered", e)
            }
        }
        receiver = null
        try {
            val bt = adapter
            if (bt != null && hasPermissions() && bt.isDiscovering) bt.cancelDiscovery()
        } catch (e: SecurityException) {
            Log.w(TAG, "cancelDiscovery denied", e)
        }
    }

    private fun finish(reason: String) {
        val s = sink
        stop()
        s?.success(mapOf("type" to "finished", "reason" to reason))
    }

    private fun hasPermissions(): Boolean {
        val needed = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            listOf(Manifest.permission.BLUETOOTH_SCAN, Manifest.permission.BLUETOOTH_CONNECT)
        } else {
            listOf(Manifest.permission.BLUETOOTH_ADMIN, Manifest.permission.ACCESS_FINE_LOCATION)
        }
        return needed.all {
            context.checkSelfPermission(it) == PackageManager.PERMISSION_GRANTED
        }
    }

    private fun register() {
        val r = object : BroadcastReceiver() {
            override fun onReceive(ctx: Context, intent: Intent) {
                when (intent.action) {
                    BluetoothDevice.ACTION_FOUND -> onFound(intent)
                    BluetoothAdapter.ACTION_DISCOVERY_FINISHED -> finish("done")
                }
            }
        }
        val filter = IntentFilter().apply {
            addAction(BluetoothDevice.ACTION_FOUND)
            addAction(BluetoothAdapter.ACTION_DISCOVERY_FINISHED)
        }
        // These are system broadcasts; the flag is required from API 33 on.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(r, filter, Context.RECEIVER_EXPORTED)
        } else {
            context.registerReceiver(r, filter)
        }
        receiver = r
    }

    @SuppressLint("MissingPermission")
    private fun onFound(intent: Intent) {
        val s = sink ?: return
        try {
            val device: BluetoothDevice = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE, BluetoothDevice::class.java)
            } else {
                @Suppress("DEPRECATION")
                intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE)
            } ?: return
            // BLE-only devices are covered by the BLE scan.
            if (device.type == BluetoothDevice.DEVICE_TYPE_LE) return
            val btClass: BluetoothClass? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                intent.getParcelableExtra(BluetoothDevice.EXTRA_CLASS, BluetoothClass::class.java)
            } else {
                @Suppress("DEPRECATION")
                intent.getParcelableExtra(BluetoothDevice.EXTRA_CLASS)
            }
            val rssi = intent.getShortExtra(BluetoothDevice.EXTRA_RSSI, Short.MIN_VALUE)
            val name = intent.getStringExtra(BluetoothDevice.EXTRA_NAME)
                ?: try { device.name } catch (e: SecurityException) { null }
            s.success(
                mapOf(
                    "type" to "found",
                    "address" to device.address,
                    "name" to (name ?: ""),
                    "rssi" to if (rssi == Short.MIN_VALUE) null else rssi.toInt(),
                    "majorDeviceClass" to btClass?.majorDeviceClass,
                    "deviceClass" to btClass?.deviceClass,
                )
            )
        } catch (e: SecurityException) {
            Log.w(TAG, "ACTION_FOUND denied", e)
        } catch (e: Exception) {
            Log.w(TAG, "ACTION_FOUND parse failed", e)
        }
    }

    companion object {
        private const val TAG = "ClassicBtDiscovery"
    }
}
