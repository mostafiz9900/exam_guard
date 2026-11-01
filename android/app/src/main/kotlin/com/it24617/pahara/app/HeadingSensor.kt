package com.it24617.pahara.app

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.SystemClock
import io.flutter.plugin.common.EventChannel

/**
 * Compass heading of the phone's top edge, tilt-compensated, from the
 * rotation-vector sensor (gyro + accelerometer + magnetometer fusion).
 * Dart listens on "exam_guard/heading" and receives [degrees 0–360 from
 * magnetic north, accuracy 0–3 (SensorManager.SENSOR_STATUS_*)] ~20 times
 * a second. Errors with code "unavailable" when the phone has no sensor.
 */
class HeadingSensor(context: Context) : EventChannel.StreamHandler, SensorEventListener {
    private val sensors = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
    private var sink: EventChannel.EventSink? = null
    private var accuracy = SensorManager.SENSOR_STATUS_UNRELIABLE
    private var lastEmit = 0L
    private val rotation = FloatArray(9)
    private val orientation = FloatArray(3)

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        val sensor = sensors.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)
            ?: sensors.getDefaultSensor(Sensor.TYPE_GEOMAGNETIC_ROTATION_VECTOR)
        if (sensor == null) {
            events.error("unavailable", "No rotation vector sensor", null)
            return
        }
        sink = events
        sensors.registerListener(this, sensor, SensorManager.SENSOR_DELAY_GAME)
    }

    override fun onCancel(arguments: Any?) = stop()

    fun stop() {
        sensors.unregisterListener(this)
        sink = null
    }

    override fun onAccuracyChanged(sensor: Sensor?, value: Int) {
        accuracy = value
    }

    override fun onSensorChanged(event: SensorEvent) {
        val now = SystemClock.elapsedRealtime()
        if (now - lastEmit < 50) return
        lastEmit = now
        SensorManager.getRotationMatrixFromVector(rotation, event.values)
        SensorManager.getOrientation(rotation, orientation)
        val degrees = (Math.toDegrees(orientation[0].toDouble()) + 360.0) % 360.0
        sink?.success(listOf(degrees, accuracy))
    }
}
