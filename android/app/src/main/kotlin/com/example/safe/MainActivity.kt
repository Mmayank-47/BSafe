package com.example.safe

import android.app.KeyguardManager
import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorManager
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.view.KeyEvent
import android.view.WindowManager
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.bitchat.android.womensafety.ShakeDetector
import com.bitchat.android.womensafety.WomenSafetySosChannelHandler

class MainActivity: FlutterActivity() {
    private val SMART_WAKE_CHANNEL = "com.example.safe/smart_wake"
    private val CHANNEL = "com.bsafe/womensafety_mesh_sos"

    private var sensorManager: SensorManager? = null
    private var accelerometer: Sensor? = null
    private var shakeDetector: ShakeDetector? = null
    private var isShakeSosEnabled: Boolean = true
    private var isVolumeComboSosEnabled: Boolean = true
    private var methodChannel: MethodChannel? = null
    private var channelHandler: WomenSafetySosChannelHandler? = null

    // Volume button pattern detection: 3x Volume Down + 1x Volume Up
    private val volumeKeyPattern = mutableListOf<Int>()
    private var lastVolumeKeyTime: Long = 0L

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        unlockScreenAndKeepOn()
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Smart Wake Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SMART_WAKE_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getLaunchType") {
                result.success("SMART_WAKE_L")
            } else {
                result.notImplemented()
            }
        }

        // Enable Always-On Display & Show over Lockscreen Window Flags
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
            keyguardManager.requestDismissKeyguard(this, null)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
            )
        }

        val handler = WomenSafetySosChannelHandler(applicationContext)
        channelHandler = handler
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel = channel

        // Initialize Shake Detector Sensor
        sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        accelerometer = sensorManager?.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        shakeDetector = ShakeDetector {
            if (isShakeSosEnabled) {
                runOnUiThread {
                    wakeUpDeviceScreen()
                    vibrateOnEmergency()
                    val record = handler.triggerEmergencySos(
                        latitude = 21.1458,
                        longitude = 79.0882,
                        batteryLevel = 95,
                        message = "🚨 SHAKE-TO-SOS! Phone shaken vigorously - Emergency help required!"
                    )
                    methodChannel?.invokeMethod("onShakeSosTriggered", record)
                }
            }
        }

        registerShakeListener()

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "initSosModule" -> {
                    val victimName = call.argument<String>("victimName") ?: "User"
                    val deviceIdHex = call.argument<String>("deviceIdHex") ?: "1122334455667788"
                    val success = handler.initSosModule(victimName, deviceIdHex)
                    result.success(success)
                }
                "triggerEmergencySos" -> {
                    wakeUpDeviceScreen()
                    val lat = call.argument<Double>("latitude") ?: 0.0
                    val lng = call.argument<Double>("longitude") ?: 0.0
                    val battery = call.argument<Int>("batteryLevel") ?: 100
                    val msg = call.argument<String>("message") ?: "EMERGENCY! Help required immediately!"
                    val res = handler.triggerEmergencySos(lat, lng, battery, msg)
                    result.success(res)
                }
                "getDeliveryStatus" -> {
                    val status = handler.getDeliveryStatus()
                    result.success(status)
                }
                "getConnectedPeersCount" -> {
                    val count = handler.getConnectedPeersCount()
                    result.success(count)
                }
                "getConnectedLiveNodesCount" -> {
                    val count = handler.getConnectedLiveNodesCount()
                    result.success(count)
                }
                "getReceivedSosRecords" -> {
                    val records = handler.getReceivedSosRecords()
                    result.success(records)
                }
                "simulateIncomingPeerSos" -> {
                    val name = call.argument<String>("victimName") ?: "Ananya Sharma"
                    val lat = call.argument<Double>("latitude") ?: 21.1462
                    val lng = call.argument<Double>("longitude") ?: 79.0890
                    val battery = call.argument<Int>("batteryLevel") ?: 85
                    val msg = call.argument<String>("message") ?: "HELP! Emergency distress signal from nearby guardian device!"
                    val record = handler.simulateIncomingPeerSos(name, lat, lng, battery, msg)
                    result.success(record)
                }
                "toggleShakeSos" -> {
                    val enable = call.argument<Boolean>("enable") ?: true
                    isShakeSosEnabled = enable
                    if (enable) registerShakeListener() else unregisterShakeListener()
                    result.success(isShakeSosEnabled)
                }
                "toggleVolumeComboSos" -> {
                    val enable = call.argument<Boolean>("enable") ?: true
                    isVolumeComboSosEnabled = enable
                    result.success(isVolumeComboSosEnabled)
                }
                "triggerShakeSosSimulation" -> {
                    runOnUiThread {
                        wakeUpDeviceScreen()
                        vibrateOnEmergency()
                        val record = handler.triggerEmergencySos(
                            latitude = 21.1458,
                            longitude = 79.0882,
                            batteryLevel = 95,
                            message = "🚨 SHAKE-TO-SOS! Phone shaken vigorously - Emergency help required!"
                        )
                        channel.invokeMethod("onShakeSosTriggered", record)
                        result.success(record)
                    }
                }
                "triggerVolumeComboSosSimulation" -> {
                    runOnUiThread {
                        val record = triggerVolumeComboSos()
                        result.success(record)
                    }
                }
                "sendDirectSms" -> {
                    val phone = call.argument<String>("phoneNumber") ?: ""
                    val msg = call.argument<String>("message") ?: ""
                    val success = sendDirectSms(phone, msg)
                    result.success(success)
                }
                "enableAlwaysOnDisplay" -> {
                    val enable = call.argument<Boolean>("enable") ?: true
                    if (enable) {
                        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    } else {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    }
                    result.success(true)
                }
                "wakeUpScreen" -> {
                    wakeUpDeviceScreen()
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun unlockScreenAndKeepOn() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
            keyguardManager.requestDismissKeyguard(this, null)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
            )
        }
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        if (isVolumeComboSosEnabled && (keyCode == KeyEvent.KEYCODE_VOLUME_DOWN || keyCode == KeyEvent.KEYCODE_VOLUME_UP)) {
            val now = System.currentTimeMillis()
            // Reset pattern if more than 4 seconds elapsed between key presses
            if (now - lastVolumeKeyTime > 4000L) {
                volumeKeyPattern.clear()
            }
            lastVolumeKeyTime = now
            volumeKeyPattern.add(keyCode)

            // Check for pattern: 3x VOLUME_DOWN + 1x VOLUME_UP
            if (volumeKeyPattern.size >= 4) {
                val last4 = volumeKeyPattern.takeLast(4)
                if (last4[0] == KeyEvent.KEYCODE_VOLUME_DOWN &&
                    last4[1] == KeyEvent.KEYCODE_VOLUME_DOWN &&
                    last4[2] == KeyEvent.KEYCODE_VOLUME_DOWN &&
                    last4[3] == KeyEvent.KEYCODE_VOLUME_UP) {

                    volumeKeyPattern.clear()
                    triggerVolumeComboSos()
                    return true // Consume key event
                }
            }
        }
        return super.onKeyDown(keyCode, event)
    }

    private fun triggerVolumeComboSos(): Map<String, Any>? {
        wakeUpDeviceScreen()
        vibrateOnEmergency()
        val handler = channelHandler ?: return null

        val record = handler.triggerEmergencySos(
            latitude = 21.1458,
            longitude = 79.0882,
            batteryLevel = 95,
            message = "🚨 HARDWARE VOLUME COMBO SOS! (3x Vol Down + 1x Vol Up triggered) - Emergency help required!"
        )

        // Send direct background SMS to emergency contacts
        val trustedContacts = listOf("+919109750185", "+919876543210")
        val mapLink = "http://maps.google.com/?q=21.1458,79.0882"
        val smsText = "🚨 HARDWARE VOLUME COMBO SOS!\nVictim: Primary User\nGPS Location: $mapLink"
        for (phone in trustedContacts) {
            sendDirectSms(phone, smsText)
        }

        methodChannel?.invokeMethod("onVolumeComboSosTriggered", record)
        return record
    }

    private fun wakeUpDeviceScreen() {
        try {
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            @Suppress("DEPRECATION")
            val wakeLock = powerManager.newWakeLock(
                PowerManager.SCREEN_BRIGHT_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP,
                "RakshaSetu:EmergencyWakeLock"
            )
            wakeLock.acquire(10000L) // Wakes up screen for 10 seconds
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Wake lock error: ${e.message}")
        }
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
            android.util.Log.i("DirectSms", "✅ Direct background SMS dispatched to $phoneNumber")
            true
        } catch (e: Exception) {
            android.util.Log.e("DirectSms", "❌ Direct SMS send failed to $phoneNumber: ${e.message}")
            false
        }
    }

    private fun registerShakeListener() {
        if (accelerometer != null && shakeDetector != null) {
            sensorManager?.registerListener(shakeDetector, accelerometer, SensorManager.SENSOR_DELAY_UI)
        }
    }

    private fun unregisterShakeListener() {
        if (shakeDetector != null) {
            sensorManager?.unregisterListener(shakeDetector)
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
            // Ignore vibration errors on emulators
        }
    }

    override fun onResume() {
        super.onResume()
        if (isShakeSosEnabled) {
            registerShakeListener()
        }
    }

    override fun onPause() {
        super.onPause()
        unregisterShakeListener()
    }
}
