package com.bitchat.android.audit

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import android.util.Log
import java.security.MessageDigest
import java.util.Date

/**
 * Event categories in the tamper-evident audit trail.
 */
enum class AuditEventType {
    ALERT_CREATED,
    ALERT_RELAYED,
    ALERT_BRIDGED,
    DELIVERY_ACK_SENT,
    DELIVERY_ACK_RECEIVED,
    ALERT_EXPIRED
}

/**
 * Audit log entry containing cryptographic hashes for tamper-evidence.
 */
data class AuditLogEntry(
    val id: Long = 0,
    val timestamp: Long = System.currentTimeMillis(),
    val eventType: AuditEventType,
    val recordIdHex: String,
    val peerIdHex: String,
    val details: String,
    val prevHash: String,
    val entryHash: String
)

/**
 * SQLite SQLiteOpenHelper for local audit logging and store-and-forward outbox persistence.
 */
class AuditLogManager(context: Context) : SQLiteOpenHelper(context, DATABASE_NAME, null, DATABASE_VERSION) {

    companion object {
        private const val TAG = "AuditLogManager"
        private const val DATABASE_NAME = "critical_data_audit.db"
        private const val DATABASE_VERSION = 1

        private const val TABLE_AUDIT = "audit_log"
        private const val TABLE_OUTBOX = "critical_outbox"

        @Volatile
        private var instance: AuditLogManager? = null

        fun getInstance(context: Context): AuditLogManager {
            return instance ?: synchronized(this) {
                instance ?: AuditLogManager(context.applicationContext).also { instance = it }
            }
        }
    }

    override fun onCreate(db: SQLiteDatabase) {
        // Table for Audit Log
        db.execSQL("""
            CREATE TABLE $TABLE_AUDIT (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp INTEGER NOT NULL,
                event_type TEXT NOT NULL,
                record_id TEXT NOT NULL,
                peer_id TEXT NOT NULL,
                details TEXT NOT NULL,
                prev_hash TEXT NOT NULL,
                entry_hash TEXT NOT NULL
            );
        """.trimIndent())

        // Table for Store-and-Forward Outbox
        db.execSQL("""
            CREATE TABLE $TABLE_OUTBOX (
                record_id TEXT PRIMARY KEY,
                alert_type INTEGER NOT NULL,
                priority INTEGER NOT NULL,
                origin_device_id TEXT NOT NULL,
                recipient_device_id TEXT,
                payload_bytes BLOB NOT NULL,
                created_timestamp INTEGER NOT NULL,
                expiry_timestamp INTEGER NOT NULL,
                status TEXT NOT NULL,
                retry_count INTEGER DEFAULT 0,
                ack_timestamp INTEGER DEFAULT 0,
                bridged_by_device_id TEXT
            );
        """.trimIndent())
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        db.execSQL("DROP TABLE IF EXISTS $TABLE_AUDIT")
        db.execSQL("DROP TABLE IF EXISTS $TABLE_OUTBOX")
        onCreate(db)
    }

    /**
     * Record an audit event with tamper-evident SHA-256 chaining.
     */
    @Synchronized
    fun logEvent(
        eventType: AuditEventType,
        recordIdHex: String,
        peerIdHex: String,
        details: String
    ): AuditLogEntry {
        val db = writableDatabase
        val timestamp = System.currentTimeMillis()

        // Fetch last hash in the chain
        var prevHash = "0000000000000000000000000000000000000000000000000000000000000000"
        val cursor = db.rawQuery("SELECT entry_hash FROM $TABLE_AUDIT ORDER BY id DESC LIMIT 1", null)
        if (cursor.moveToFirst()) {
            prevHash = cursor.getString(0)
        }
        cursor.close()

        // Compute current entry hash
        val entryData = "$timestamp|${eventType.name}|$recordIdHex|$peerIdHex|$details|$prevHash"
        val entryHash = sha256(entryData)

        val values = ContentValues().apply {
            put("timestamp", timestamp)
            put("event_type", eventType.name)
            put("record_id", recordIdHex)
            put("peer_id", peerIdHex)
            put("details", details)
            put("prev_hash", prevHash)
            put("entry_hash", entryHash)
        }

        val id = db.insert(TABLE_AUDIT, null, values)
        Log.i(TAG, "🔒 Audit event logged: ${eventType.name} for record ${recordIdHex.take(8)} (Hash: ${entryHash.take(8)})")

        return AuditLogEntry(
            id = id,
            timestamp = timestamp,
            eventType = eventType,
            recordIdHex = recordIdHex,
            peerIdHex = peerIdHex,
            details = details,
            prevHash = prevHash,
            entryHash = entryHash
        )
    }

    /**
     * Fetch recent audit log entries for UI display.
     */
    fun getRecentAuditEntries(limit: Int = 100): List<AuditLogEntry> {
        val list = mutableListOf<AuditLogEntry>()
        val db = readableDatabase
        val cursor = db.rawQuery("SELECT id, timestamp, event_type, record_id, peer_id, details, prev_hash, entry_hash FROM $TABLE_AUDIT ORDER BY id DESC LIMIT $limit", null)
        
        while (cursor.moveToNext()) {
            list.add(
                AuditLogEntry(
                    id = cursor.getLong(0),
                    timestamp = cursor.getLong(1),
                    eventType = try { AuditEventType.valueOf(cursor.getString(2)) } catch (e: Exception) { AuditEventType.ALERT_CREATED },
                    recordIdHex = cursor.getString(3),
                    peerIdHex = cursor.getString(4),
                    details = cursor.getString(5),
                    prevHash = cursor.getString(6),
                    entryHash = cursor.getString(7)
                )
            )
        }
        cursor.close()
        return list
    }

    /**
     * Verify integrity of the audit log chain. Returns true if untampered.
     */
    fun verifyAuditIntegrity(): Boolean {
        val db = readableDatabase
        val cursor = db.rawQuery("SELECT id, timestamp, event_type, record_id, peer_id, details, prev_hash, entry_hash FROM $TABLE_AUDIT ORDER BY id ASC", null)

        var expectedPrevHash = "0000000000000000000000000000000000000000000000000000000000000000"
        while (cursor.moveToNext()) {
            val timestamp = cursor.getLong(1)
            val eventType = cursor.getString(2)
            val recordIdHex = cursor.getString(3)
            val peerIdHex = cursor.getString(4)
            val details = cursor.getString(5)
            val prevHash = cursor.getString(6)
            val entryHash = cursor.getString(7)

            if (prevHash != expectedPrevHash) {
                Log.e(TAG, "❌ Audit integrity failure at ID ${cursor.getLong(0)}: prevHash mismatch")
                cursor.close()
                return false
            }

            val expectedEntryHash = sha256("$timestamp|$eventType|$recordIdHex|$peerIdHex|$details|$prevHash")
            if (entryHash != expectedEntryHash) {
                Log.e(TAG, "❌ Audit integrity failure at ID ${cursor.getLong(0)}: entryHash mismatch")
                cursor.close()
                return false
            }

            expectedPrevHash = entryHash
        }
        cursor.close()
        return true
    }

    private fun sha256(input: String): String {
        val digest = MessageDigest.getInstance("SHA-256")
        val hash = digest.digest(input.toByteArray(Charsets.UTF_8))
        return hash.joinToString("") { "%02x".format(it) }
    }
}
