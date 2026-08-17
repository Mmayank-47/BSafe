package com.bitchat.android.audit

import android.content.ContentValues
import android.content.Context
import android.util.Log
import com.bitchat.android.model.CriticalAlertPayload
import com.bitchat.android.model.MessagePriority
import com.bitchat.android.util.toHexString

enum class OutboxStatus {
    QUEUED,
    RELAYING,
    BRIDGED,
    DELIVERED,
    EXPIRED
}

data class OutboxRecord(
    val recordIdHex: String,
    val alertType: UShort,
    val priority: MessagePriority,
    val originDeviceIdHex: String,
    val recipientDeviceIdHex: String?,
    val payloadBytes: ByteArray,
    val createdTimestamp: Long,
    val expiryTimestamp: Long,
    val status: OutboxStatus,
    val retryCount: Int,
    val ackTimestamp: Long,
    val bridgedByDeviceIdHex: String?
)

class CriticalOutboxRepository(private val context: Context) {
    private val dbHelper = AuditLogManager.getInstance(context)

    companion object {
        private const val TAG = "CriticalOutboxRepository"
        private const val TABLE_OUTBOX = "critical_outbox"
    }

    fun saveAlert(
        payload: CriticalAlertPayload,
        priority: MessagePriority,
        recipientDeviceIdHex: String? = null,
        expiryMs: Long = 24 * 3600 * 1000L
    ): Boolean {
        val db = dbHelper.writableDatabase
        val recordIdHex = payload.recordId.toHexString()
        val originIdHex = payload.originDeviceId.toHexString()
        val created = payload.timestamp.toLong()
        val expiry = created + expiryMs

        val values = ContentValues().apply {
            put("record_id", recordIdHex)
            put("alert_type", payload.alertType.toInt())
            put("priority", priority.value.toInt())
            put("origin_device_id", originIdHex)
            put("recipient_device_id", recipientDeviceIdHex)
            put("payload_bytes", payload.toBinaryPayload())
            put("created_timestamp", created)
            put("expiry_timestamp", expiry)
            put("status", OutboxStatus.QUEUED.name)
            put("retry_count", 0)
            put("ack_timestamp", 0)
            put("bridged_by_device_id", null as String?)
        }

        val result = db.insertWithOnConflict(TABLE_OUTBOX, null, values, android.database.sqlite.SQLiteDatabase.CONFLICT_REPLACE)
        if (result != -1L) {
            dbHelper.logEvent(
                eventType = AuditEventType.ALERT_CREATED,
                recordIdHex = recordIdHex,
                peerIdHex = originIdHex,
                details = "Created alert record (Priority: ${priority.name}, Type: 0x${payload.alertType.toString(16)})"
            )
            return true
        }
        return false
    }

    fun markDelivered(recordIdHex: String, ackTimestamp: Long, bridgedByHex: String? = null): Boolean {
        val db = dbHelper.writableDatabase
        val values = ContentValues().apply {
            put("status", OutboxStatus.DELIVERED.name)
            put("ack_timestamp", ackTimestamp)
            put("bridged_by_device_id", bridgedByHex)
        }

        val updated = db.update(TABLE_OUTBOX, values, "record_id = ?", arrayOf(recordIdHex))
        if (updated > 0) {
            dbHelper.logEvent(
                eventType = AuditEventType.DELIVERY_ACK_RECEIVED,
                recordIdHex = recordIdHex,
                peerIdHex = bridgedByHex ?: "destination",
                details = "Received delivery acknowledgment at $ackTimestamp (Bridged: ${bridgedByHex != null})"
            )
            return true
        }
        return false
    }

    fun markBridged(recordIdHex: String, bridgeNodeHex: String): Boolean {
        val db = dbHelper.writableDatabase
        val values = ContentValues().apply {
            put("status", OutboxStatus.BRIDGED.name)
            put("bridged_by_device_id", bridgeNodeHex)
        }

        val updated = db.update(TABLE_OUTBOX, values, "record_id = ?", arrayOf(recordIdHex))
        if (updated > 0) {
            dbHelper.logEvent(
                eventType = AuditEventType.ALERT_BRIDGED,
                recordIdHex = recordIdHex,
                peerIdHex = bridgeNodeHex,
                details = "Alert bridged to backend API by node $bridgeNodeHex"
            )
            return true
        }
        return false
    }

    fun getAllRecords(): List<OutboxRecord> {
        val list = mutableListOf<OutboxRecord>()
        val db = dbHelper.readableDatabase
        val cursor = db.rawQuery("SELECT record_id, alert_type, priority, origin_device_id, recipient_device_id, payload_bytes, created_timestamp, expiry_timestamp, status, retry_count, ack_timestamp, bridged_by_device_id FROM $TABLE_OUTBOX ORDER BY priority DESC, created_timestamp DESC", null)

        while (cursor.moveToNext()) {
            list.add(
                OutboxRecord(
                    recordIdHex = cursor.getString(0),
                    alertType = cursor.getInt(1).toUShort(),
                    priority = MessagePriority.fromValue(cursor.getInt(2).toUByte()),
                    originDeviceIdHex = cursor.getString(3),
                    recipientDeviceIdHex = cursor.getString(4),
                    payloadBytes = cursor.getBlob(5),
                    createdTimestamp = cursor.getLong(6),
                    expiryTimestamp = cursor.getLong(7),
                    status = try { OutboxStatus.valueOf(cursor.getString(8)) } catch (e: Exception) { OutboxStatus.QUEUED },
                    retryCount = cursor.getInt(9),
                    ackTimestamp = cursor.getLong(10),
                    bridgedByDeviceIdHex = cursor.getString(11)
                )
            )
        }
        cursor.close()
        return list
    }
}
