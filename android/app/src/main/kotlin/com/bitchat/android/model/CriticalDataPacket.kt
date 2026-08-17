package com.bitchat.android.model

import android.os.Parcelable
import kotlinx.parcelize.Parcelize
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.UUID

/**
 * Priority levels for Critical Data Packets.
 * Higher priority packets are ordered first in outbox queues, allocated higher TTL,
 * and retried more aggressively.
 */
enum class MessagePriority(val value: UByte) {
    LOW(1u),
    NORMAL(2u),
    HIGH(3u),
    CRITICAL(4u);

    companion object {
        fun fromValue(value: UByte): MessagePriority {
            return values().find { it.value == value } ?: NORMAL
        }
    }
}

/**
 * Categorization of Critical Data Alerts.
 */
object CriticalAlertType {
    const val SOS_EMERGENCY: UShort = 0x0001u
    const val HEALTH_MEDICAL: UShort = 0x0002u
    const val INFRASTRUCTURE_HAZARD: UShort = 0x0003u
    const val STATUS_TELEMETRY: UShort = 0x0004u
    const val CUSTOM_ALERT: UShort = 0x0005u

    fun getLabel(type: UShort): String {
        return when (type) {
            SOS_EMERGENCY -> "SOS / Emergency"
            HEALTH_MEDICAL -> "Medical / Health Alert"
            INFRASTRUCTURE_HAZARD -> "Infrastructure Hazard"
            STATUS_TELEMETRY -> "Status / Telemetry"
            CUSTOM_ALERT -> "Custom Alert"
            else -> "Unknown Alert Type (0x${type.toString(16)})"
        }
    }
}

/**
 * Structured binary payload for Critical Alerts (MessageType 0x30).
 *
 * Payload binary format:
 * - Record UUID: 16 bytes
 * - Alert Type: 2 bytes (UShort, big-endian)
 * - Timestamp: 8 bytes (ULong, big-endian)
 * - Sequence Num: 4 bytes (UInt, big-endian)
 * - Origin Device ID: 8 bytes
 * - Payload Len: 2 bytes (UShort, big-endian)
 * - Custom Payload Data: N bytes
 * - Flags: 1 byte (bit 0: hasSignature)
 * - Signature: 64 bytes Ed25519 (optional, if flag set)
 */
@Parcelize
data class CriticalAlertPayload(
    val recordId: ByteArray = UUIDToBytes(UUID.randomUUID()),
    val alertType: UShort = CriticalAlertType.SOS_EMERGENCY,
    val timestamp: ULong = System.currentTimeMillis().toULong(),
    val sequenceNum: UInt = 0u,
    val originDeviceId: ByteArray,
    val payloadData: ByteArray,
    var signature: ByteArray? = null
) : Parcelable {

    fun toBinaryPayload(): ByteArray {
        val payloadLen = payloadData.size.coerceAtMost(0xFFFF)
        val hasSig = signature != null && signature!!.size == 64
        val capacity = 16 + 2 + 8 + 4 + 8 + 2 + payloadLen + 1 + (if (hasSig) 64 else 0)

        val buffer = ByteBuffer.allocate(capacity).apply { order(ByteOrder.BIG_ENDIAN) }
        buffer.put(recordId.take(16).toByteArray().let { if (it.size < 16) it + ByteArray(16 - it.size) else it })
        buffer.putShort(alertType.toShort())
        buffer.putLong(timestamp.toLong())
        buffer.putInt(sequenceNum.toInt())
        buffer.put(originDeviceId.take(8).toByteArray().let { if (it.size < 8) it + ByteArray(8 - it.size) else it })
        buffer.putShort(payloadLen.toShort())
        buffer.put(payloadData, 0, payloadLen)

        var flags: UByte = 0u
        if (hasSig) flags = flags or 0x01u
        buffer.put(flags.toByte())

        if (hasSig) {
            buffer.put(signature!!, 0, 64)
        }

        return buffer.array()
    }

    /**
     * Binary representation constructed specifically for Ed25519 signature signing/verification.
     * Excludes the signature byte field itself.
     */
    fun toBinaryDataForSigning(): ByteArray {
        val payloadLen = payloadData.size.coerceAtMost(0xFFFF)
        val capacity = 16 + 2 + 8 + 4 + 8 + 2 + payloadLen

        val buffer = ByteBuffer.allocate(capacity).apply { order(ByteOrder.BIG_ENDIAN) }
        buffer.put(recordId.take(16).toByteArray().let { if (it.size < 16) it + ByteArray(16 - it.size) else it })
        buffer.putShort(alertType.toShort())
        buffer.putLong(timestamp.toLong())
        buffer.putInt(sequenceNum.toInt())
        buffer.put(originDeviceId.take(8).toByteArray().let { if (it.size < 8) it + ByteArray(8 - it.size) else it })
        buffer.putShort(payloadLen.toShort())
        buffer.put(payloadData, 0, payloadLen)

        return buffer.array()
    }

    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (javaClass != other?.javaClass) return false
        other as CriticalAlertPayload
        return recordId.contentEquals(other.recordId) &&
               alertType == other.alertType &&
               timestamp == other.timestamp &&
               sequenceNum == other.sequenceNum &&
               originDeviceId.contentEquals(other.originDeviceId) &&
               payloadData.contentEquals(other.payloadData) &&
               (signature?.contentEquals(other.signature ?: byteArrayOf()) ?: (other.signature == null))
    }

    override fun hashCode(): Int {
        var result = recordId.contentHashCode()
        result = 31 * result + alertType.hashCode()
        result = 31 * result + timestamp.hashCode()
        result = 31 * result + sequenceNum.hashCode()
        result = 31 * result + originDeviceId.contentHashCode()
        result = 31 * result + payloadData.contentHashCode()
        result = 31 * result + (signature?.contentHashCode() ?: 0)
        return result
    }

    companion object {
        fun fromBinaryPayload(data: ByteArray): CriticalAlertPayload? {
            if (data.size < 16 + 2 + 8 + 4 + 8 + 2 + 1) return null
            try {
                val buffer = ByteBuffer.wrap(data).apply { order(ByteOrder.BIG_ENDIAN) }
                val recordId = ByteArray(16)
                buffer.get(recordId)

                val alertType = buffer.getShort().toUShort()
                val timestamp = buffer.getLong().toULong()
                val sequenceNum = buffer.getInt().toUInt()

                val originDeviceId = ByteArray(8)
                buffer.get(originDeviceId)

                val payloadLen = buffer.getShort().toUShort().toInt()
                if (buffer.remaining() < payloadLen + 1) return null

                val payloadData = ByteArray(payloadLen)
                buffer.get(payloadData)

                val flags = buffer.get().toUByte()
                val hasSig = (flags and 0x01u) != 0u.toUByte()

                val signature = if (hasSig && buffer.remaining() >= 64) {
                    val sig = ByteArray(64)
                    buffer.get(sig)
                    sig
                } else null

                return CriticalAlertPayload(
                    recordId = recordId,
                    alertType = alertType,
                    timestamp = timestamp,
                    sequenceNum = sequenceNum,
                    originDeviceId = originDeviceId,
                    payloadData = payloadData,
                    signature = signature
                )
            } catch (e: Exception) {
                return null
            }
        }

        fun UUIDToBytes(uuid: UUID): ByteArray {
            val bb = ByteBuffer.allocate(16).apply { order(ByteOrder.BIG_ENDIAN) }
            bb.putLong(uuid.mostSignificantBits)
            bb.putLong(uuid.leastSignificantBits)
            return bb.array()
        }

        fun bytesToUUID(bytes: ByteArray): UUID? {
            if (bytes.size < 16) return null
            val bb = ByteBuffer.wrap(bytes).apply { order(ByteOrder.BIG_ENDIAN) }
            return UUID(bb.long, bb.long)
        }
    }
}

/**
 * Structured binary payload for Delivery Acknowledgment (MessageType 0x31).
 *
 * Payload binary format:
 * - Record UUID: 16 bytes (matches original CriticalAlertPayload.recordId)
 * - Origin Device ID: 8 bytes (ID of node that created alert)
 * - Ack Timestamp: 8 bytes (ULong epoch millis)
 * - Flags: 1 byte (bit 0: isBridged, bit 1: hasSignature)
 * - Bridged By Device ID: 8 bytes (optional, node ID that relayed to internet)
 * - Ack Signature: 64 bytes Ed25519 (optional)
 */
@Parcelize
data class DeliveryAckPayload(
    val recordId: ByteArray,
    val originDeviceId: ByteArray,
    val ackTimestamp: ULong = System.currentTimeMillis().toULong(),
    val isBridged: Boolean = false,
    val bridgedByDeviceId: ByteArray? = null,
    var signature: ByteArray? = null
) : Parcelable {

    fun toBinaryPayload(): ByteArray {
        val hasBridgedId = isBridged && bridgedByDeviceId != null
        val hasSig = signature != null && signature!!.size == 64
        val capacity = 16 + 8 + 8 + 1 + (if (hasBridgedId) 8 else 0) + (if (hasSig) 64 else 0)

        val buffer = ByteBuffer.allocate(capacity).apply { order(ByteOrder.BIG_ENDIAN) }
        buffer.put(recordId.take(16).toByteArray().let { if (it.size < 16) it + ByteArray(16 - it.size) else it })
        buffer.put(originDeviceId.take(8).toByteArray().let { if (it.size < 8) it + ByteArray(8 - it.size) else it })
        buffer.putLong(ackTimestamp.toLong())

        var flags: UByte = 0u
        if (isBridged) flags = flags or 0x01u
        if (hasSig) flags = flags or 0x02u
        buffer.put(flags.toByte())

        if (hasBridgedId) {
            buffer.put(bridgedByDeviceId.take(8).toByteArray().let { if (it.size < 8) it + ByteArray(8 - it.size) else it })
        }
        if (hasSig) {
            buffer.put(signature!!, 0, 64)
        }

        return buffer.array()
    }

    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (javaClass != other?.javaClass) return false
        other as DeliveryAckPayload
        return recordId.contentEquals(other.recordId) &&
               originDeviceId.contentEquals(other.originDeviceId) &&
               ackTimestamp == other.ackTimestamp &&
               isBridged == other.isBridged &&
               (bridgedByDeviceId?.contentEquals(other.bridgedByDeviceId ?: byteArrayOf()) ?: (other.bridgedByDeviceId == null))
    }

    override fun hashCode(): Int {
        var result = recordId.contentHashCode()
        result = 31 * result + originDeviceId.contentHashCode()
        result = 31 * result + ackTimestamp.hashCode()
        result = 31 * result + isBridged.hashCode()
        result = 31 * result + (bridgedByDeviceId?.contentHashCode() ?: 0)
        return result
    }

    companion object {
        fun fromBinaryPayload(data: ByteArray): DeliveryAckPayload? {
            if (data.size < 16 + 8 + 8 + 1) return null
            try {
                val buffer = ByteBuffer.wrap(data).apply { order(ByteOrder.BIG_ENDIAN) }
                val recordId = ByteArray(16)
                buffer.get(recordId)

                val originDeviceId = ByteArray(8)
                buffer.get(originDeviceId)

                val ackTimestamp = buffer.getLong().toULong()
                val flags = buffer.get().toUByte()

                val isBridged = (flags and 0x01u) != 0u.toUByte()
                val hasSig = (flags and 0x02u) != 0u.toUByte()

                val bridgedByDeviceId = if (isBridged && buffer.remaining() >= 8) {
                    val id = ByteArray(8)
                    buffer.get(id)
                    id
                } else null

                val signature = if (hasSig && buffer.remaining() >= 64) {
                    val sig = ByteArray(64)
                    buffer.get(sig)
                    sig
                } else null

                return DeliveryAckPayload(
                    recordId = recordId,
                    originDeviceId = originDeviceId,
                    ackTimestamp = ackTimestamp,
                    isBridged = isBridged,
                    bridgedByDeviceId = bridgedByDeviceId,
                    signature = signature
                )
            } catch (e: Exception) {
                return null
            }
        }
    }
}
