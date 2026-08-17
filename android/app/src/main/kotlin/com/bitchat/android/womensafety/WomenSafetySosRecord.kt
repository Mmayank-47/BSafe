package com.bitchat.android.womensafety

import android.os.Parcelable
import com.bitchat.android.model.CriticalAlertPayload
import kotlinx.parcelize.Parcelize
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.UUID

/**
 * Structured binary payload for Women's Safety Emergency SOS Records.
 *
 * Payload format:
 * - SOS Record UUID: 16 bytes
 * - Victim Device ID: 8 bytes
 * - Timestamp: 8 bytes (ULong epoch millis)
 * - Latitude: 8 bytes (Double)
 * - Longitude: 8 bytes (Double)
 * - Battery Level: 1 byte (0..100)
 * - Victim Name Len: 1 byte
 * - Victim Name: N bytes UTF-8
 * - Message Len: 2 bytes (UShort)
 * - Custom Message: M bytes UTF-8
 * - Flags: 1 byte (bit 0: hasSignature)
 * - Signature: 64 bytes Ed25519 (optional)
 */
@Parcelize
data class WomenSafetySosRecord(
    val sosId: ByteArray = CriticalAlertPayload.UUIDToBytes(UUID.randomUUID()),
    val victimDeviceId: ByteArray,
    val timestamp: ULong = System.currentTimeMillis().toULong(),
    val latitude: Double,
    val longitude: Double,
    val batteryLevel: Int = 100,
    val victimName: String,
    val customMessage: String = "EMERGENCY: Help required immediately!",
    var signature: ByteArray? = null
) : Parcelable {

    fun toBinaryPayload(): ByteArray {
        val nameBytes = victimName.toByteArray(Charsets.UTF_8).take(255).toByteArray()
        val msgBytes = customMessage.toByteArray(Charsets.UTF_8).take(0xFFFF).toByteArray()
        val hasSig = signature != null && signature!!.size == 64

        val capacity = 16 + 8 + 8 + 8 + 8 + 1 + 1 + nameBytes.size + 2 + msgBytes.size + 1 + (if (hasSig) 64 else 0)
        val buffer = ByteBuffer.allocate(capacity).apply { order(ByteOrder.BIG_ENDIAN) }

        buffer.put(sosId.take(16).toByteArray().let { if (it.size < 16) it + ByteArray(16 - it.size) else it })
        buffer.put(victimDeviceId.take(8).toByteArray().let { if (it.size < 8) it + ByteArray(8 - it.size) else it })
        buffer.putLong(timestamp.toLong())
        buffer.putDouble(latitude)
        buffer.putDouble(longitude)
        buffer.put(batteryLevel.coerceIn(0, 100).toByte())

        buffer.put(nameBytes.size.toByte())
        buffer.put(nameBytes)

        buffer.putShort(msgBytes.size.toShort())
        buffer.put(msgBytes)

        var flags: UByte = 0u
        if (hasSig) flags = flags or 0x01u
        buffer.put(flags.toByte())

        if (hasSig) {
            buffer.put(signature!!, 0, 64)
        }

        return buffer.array()
    }

    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (javaClass != other?.javaClass) return false
        other as WomenSafetySosRecord
        return sosId.contentEquals(other.sosId) &&
               victimDeviceId.contentEquals(other.victimDeviceId) &&
               timestamp == other.timestamp &&
               latitude == other.latitude &&
               longitude == other.longitude &&
               victimName == other.victimName &&
               customMessage == other.customMessage
    }

    override fun hashCode(): Int {
        var result = sosId.contentHashCode()
        result = 31 * result + victimDeviceId.contentHashCode()
        result = 31 * result + timestamp.hashCode()
        result = 31 * result + latitude.hashCode()
        result = 31 * result + longitude.hashCode()
        result = 31 * result + victimName.hashCode()
        result = 31 * result + customMessage.hashCode()
        return result
    }

    companion object {
        fun fromBinaryPayload(data: ByteArray): WomenSafetySosRecord? {
            if (data.size < 16 + 8 + 8 + 8 + 8 + 1 + 1 + 2 + 1) return null
            try {
                val buffer = ByteBuffer.wrap(data).apply { order(ByteOrder.BIG_ENDIAN) }

                val sosId = ByteArray(16)
                buffer.get(sosId)

                val victimDeviceId = ByteArray(8)
                buffer.get(victimDeviceId)

                val timestamp = buffer.getLong().toULong()
                val latitude = buffer.getDouble()
                val longitude = buffer.getDouble()
                val batteryLevel = buffer.get().toInt() and 0xFF

                val nameLen = buffer.get().toInt() and 0xFF
                if (buffer.remaining() < nameLen + 2) return null
                val nameBytes = ByteArray(nameLen)
                buffer.get(nameBytes)
                val victimName = String(nameBytes, Charsets.UTF_8)

                val msgLen = buffer.getShort().toUShort().toInt()
                if (buffer.remaining() < msgLen + 1) return null
                val msgBytes = ByteArray(msgLen)
                buffer.get(msgBytes)
                val customMessage = String(msgBytes, Charsets.UTF_8)

                val flags = buffer.get().toUByte()
                val hasSig = (flags and 0x01u) != 0u.toUByte()

                val signature = if (hasSig && buffer.remaining() >= 64) {
                    val sig = ByteArray(64)
                    buffer.get(sig)
                    sig
                } else null

                return WomenSafetySosRecord(
                    sosId = sosId,
                    victimDeviceId = victimDeviceId,
                    timestamp = timestamp,
                    latitude = latitude,
                    longitude = longitude,
                    batteryLevel = batteryLevel,
                    victimName = victimName,
                    customMessage = customMessage,
                    signature = signature
                )
            } catch (e: Exception) {
                return null
            }
        }
    }
}
