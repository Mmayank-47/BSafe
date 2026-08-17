package com.bitchat.android.womensafety

import android.content.Context
import com.bitchat.android.audit.OutboxStatus

/**
 * Interface handler for Women's Safety Offline BLE Mesh SOS.
 * Serves as the bridge between Flutter/React-Native host applications and the native Kotlin engine.
 */
class WomenSafetySosChannelHandler(private val context: Context) {

    private val sosManager = WomenSafetyMeshSosManager.getInstance(context)

    fun initSosModule(victimName: String, deviceIdHex: String): Boolean {
        sosManager.victimName = victimName
        sosManager.myDeviceIdHex = deviceIdHex
        return true
    }

    fun triggerEmergencySos(
        latitude: Double,
        longitude: Double,
        batteryLevel: Int = 100,
        message: String = "EMERGENCY! Help required immediately!"
    ): Map<String, Any> {
        val record = sosManager.triggerEmergencySos(latitude, longitude, batteryLevel, message)
        return mapOf(
            "sosIdHex" to record.sosId.joinToString("") { "%02x".format(it) },
            "victimName" to record.victimName,
            "latitude" to record.latitude,
            "longitude" to record.longitude,
            "timestamp" to record.timestamp.toLong(),
            "status" to OutboxStatus.RELAYING.name
        )
    }

    fun getDeliveryStatus(): String {
        return sosManager.activeSosStatus.value.name
    }

    fun getConnectedPeersCount(): Int {
        return sosManager.getConnectedLiveNodesCount()
    }

    fun getConnectedLiveNodesCount(): Int {
        return sosManager.getConnectedLiveNodesCount()
    }

    fun getReceivedSosRecords(): List<Map<String, Any>> {
        return sosManager.getReceivedSosRecords().map { record ->
            mapOf(
                "sosIdHex" to record.sosId.joinToString("") { "%02x".format(it) },
                "victimDeviceIdHex" to record.victimDeviceId.joinToString("") { "%02x".format(it) },
                "victimName" to record.victimName,
                "latitude" to record.latitude,
                "longitude" to record.longitude,
                "batteryLevel" to record.batteryLevel,
                "customMessage" to record.customMessage,
                "timestamp" to record.timestamp.toLong(),
                "status" to "RECEIVED_VIA_BLE_MESH"
            )
        }
    }

    fun simulateIncomingPeerSos(
        victimName: String,
        latitude: Double,
        longitude: Double,
        batteryLevel: Int,
        message: String
    ): Map<String, Any> {
        val record = sosManager.simulateIncomingPeerSos(victimName, latitude, longitude, batteryLevel, message)
        return mapOf(
            "sosIdHex" to record.sosId.joinToString("") { "%02x".format(it) },
            "victimDeviceIdHex" to record.victimDeviceId.joinToString("") { "%02x".format(it) },
            "victimName" to record.victimName,
            "latitude" to record.latitude,
            "longitude" to record.longitude,
            "batteryLevel" to record.batteryLevel,
            "customMessage" to record.customMessage,
            "timestamp" to record.timestamp.toLong(),
            "status" to "RECEIVED_VIA_BLE_MESH"
        )
    }
}
