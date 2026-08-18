package com.example.safe

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.hardware.Sensor
import android.hardware.SensorManager
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.util.Log
import androidx.core.app.NotificationCompat
import com.bitchat.android.womensafety.ShakeDetector
import com.bitchat.android.womensafety.WomenSafetySosChannelHandler

class SosForegroundService : Service() {

    companion object {
        private const val TAG = "SosForegroundService"
        const val CHANNEL_ID = "bsafe_sos_fg_channel"
        const val NOTIFICATION_ID = 9991
        const val ACTION_START = "com.example.safe.ACTION_START_SOS_SERVICE"
        const val ACTION_STOP = "com.example.safe.ACTION_STOP_SOS_SERVICE"
        const val ACTION_SHAKE_TRIGGERED = "com.example.safe.ACTION_SHAKE_SOS_TRIGGERED"
    }

    private var sensorManager: SensorManager? = null
    private var accelerometer: Sensor? = null
    private var shakeDetector: ShakeDetector? = null
    private var isShakeSosEnabled: Boolean = true

    override fun onCreate() {
        super.onCreate()
        Log.i(TAG, "⚡ SosForegroundService onCreate called - Initializing Always-On Shake Detector")
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, buildForegroundNotification())

        sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        accelerometer = sensorManager?.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)

        shakeDetector = ShakeDetector {
            if (isShakeSosEnabled) {
                Log.w(TAG, "🚨 SHAKE-TO-SOS DETECTED IN BACKGROUND SERVICE!")
                handleShakeSosEmergencyTrigger()
            }
        }

        registerShakeListener()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action
        Log.i(TAG, "SosForegroundService onStartCommand with action: $action")
        if (action == ACTION_STOP) {
            unregisterShakeListener()
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
            return START_NOT_STICKY
        }

        registerShakeListener()
        return START_STICKY
    }

    private fun registerShakeListener() {
        if (accelerometer != null && shakeDetector != null) {
            sensorManager?.registerListener(shakeDetector, accelerometer, SensorManager.SENSOR_DELAY_UI)
            Log.i(TAG, "✅ Accelerometer shake listener registered in Foreground Service")
        }
    }

    private fun unregisterShakeListener() {
        if (shakeDetector != null) {
            sensorManager?.unregisterListener(shakeDetector)
            Log.i(TAG, "🛑 Accelerometer shake listener unregistered in Foreground Service")
        }
    }

    private fun handleShakeSosEmergencyTrigger() {
        wakeUpDeviceScreen()
        vibrateOnEmergency()

        val handler = WomenSafetySosChannelHandler(applicationContext)
        val record = handler.triggerEmergencySos(
            latitude = 21.1458,
            longitude = 79.0882,
            batteryLevel = 95,
            message = "🚨 BACKGROUND SHAKE-TO-SOS! Vigorous phone shake detected in background service!"
        )

        sendDirectSms("9109750185", "🚨 BACKGROUND RED ALERT: Shake-to-SOS Triggered in Background! Immediate help required! GPS: https://maps.google.com/?q=21.1458,79.0882")

        // Send broadcast to MainActivity if active
        val broadcastIntent = Intent(ACTION_SHAKE_TRIGGERED).apply {
            putExtra("sosRecord", HashMap(record))
        }
        sendBroadcast(broadcastIntent)

        // Also notify user via high-priority notification
        showEmergencyTriggerNotification()
    }

    private fun wakeUpDeviceScreen() {
        try {
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            @Suppress("DEPRECATION")
            val wakeLock = powerManager.newWakeLock(
                PowerManager.SCREEN_BRIGHT_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP,
                "bSafe:EmergencyForegroundWakeLock"
            )
            wakeLock.acquire(10000L)
        } catch (e: Exception) {
            Log.e(TAG, "Wake lock acquisition failed: ${e.message}")
        }
    }

    private fun vibrateOnEmergency() {
        try {
            @Suppress("DEPRECATION")
            val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator.vibrate(VibrationEffect.createOneShot(500, VibrationEffect.DEFAULT_AMPLITUDE))
            } else {
                vibrator.vibrate(500)
            }
        } catch (e: Exception) {
            // Ignore vibration errors
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "RakshaSetu Safety Monitor",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Always-on background monitoring for Shake & Hardware Emergency SOS triggers"
                setShowBadge(false)
            }
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun buildForegroundNotification(): Notification {
        val launchIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("RakshaSetu Safety Protection Active")
            .setContentText("Monitoring Shake & Hardware SOS triggers in background")
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .setContentIntent(pendingIntent)
            .build()
    }

    private fun showEmergencyTriggerNotification() {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val emergencyChannelId = "bsafe_emergency_alert_channel"

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                emergencyChannelId,
                "RakshaSetu Emergency Alerts",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Critical alerts when Emergency SOS is triggered"
                enableVibration(true)
            }
            notificationManager.createNotificationChannel(channel)
        }

        val launchIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val emergencyNotification = NotificationCompat.Builder(this, emergencyChannelId)
            .setContentTitle("🚨 EMERGENCY SOS TRIGGERED!")
            .setContentText("Shake-to-SOS detected! Emergency distress signal broadcasting to BLE Mesh.")
            .setSmallIcon(android.R.drawable.stat_sys_warning)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()

        notificationManager.notify(NOTIFICATION_ID + 1, emergencyNotification)
    }

    private fun sendDirectSms(phoneNumber: String, message: String): Boolean {
        return try {
            val smsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                applicationContext.getSystemService(android.telephony.SmsManager::class.java)
            } else {
                @Suppress("DEPRECATION")
                android.telephony.SmsManager.getDefault()
            }
            val parts = smsManager.divideMessage(message)
            smsManager.sendMultipartTextMessage(phoneNumber, null, parts, null, null)
            Log.i(TAG, "✅ Direct background SMS dispatched to $phoneNumber")
            true
        } catch (e: Exception) {
            Log.e(TAG, "❌ Direct SMS send failed to $phoneNumber: ${e.message}")
            false
        }
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.i(TAG, "SosForegroundService onDestroy called - Stopping shake detector")
        unregisterShakeListener()
    }
}
