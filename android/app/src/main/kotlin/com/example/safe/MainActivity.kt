package com.example.safe

import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.bitchat.android.womensafety.WomenSafetySosChannelHandler

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.bsafe/womensafety_mesh_sos"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val handler = WomenSafetySosChannelHandler(applicationContext)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "initSosModule" -> {
                    val victimName = call.argument<String>("victimName") ?: "User"
                    val deviceIdHex = call.argument<String>("deviceIdHex") ?: "1122334455667788"
                    val success = handler.initSosModule(victimName, deviceIdHex)
                    result.success(success)
                }
                "triggerEmergencySos" -> {
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
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}

