package com.bitchat.android.womensafety

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import com.bitchat.android.audit.AuditEventType
import com.bitchat.android.audit.AuditLogManager
import com.bitchat.android.audit.CriticalOutboxRepository
import com.bitchat.android.audit.OutboxStatus
import com.bitchat.android.model.CriticalAlertPayload
import com.bitchat.android.model.CriticalAlertType
import com.bitchat.android.model.DeliveryAckPayload
import com.bitchat.android.model.MessagePriority
import com.bitchat.android.net.TransportSelector
import com.bitchat.android.protocol.BinaryProtocol
import com.bitchat.android.protocol.BitchatPacket
import com.bitchat.android.protocol.MessageType
import com.bitchat.android.util.toHexString
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow

class WomenSafetyMeshSosManager private constructor(private val appContext: Context) {

    companion object {
        private const val TAG = "WomenSafetyMeshSos"
        private const val CHANNEL_ID = "women_safety_sos_channel"

        @Volatile
        private var instance: WomenSafetyMeshSosManager? = null

        fun getInstance(context: Context): WomenSafetyMeshSosManager {
            return instance ?: synchronized(this) {
                instance ?: WomenSafetyMeshSosManager(context.applicationContext).also { instance = it }
            }
        }
    }

    private val auditLogManager = AuditLogManager.getInstance(appContext)
    private val outboxRepository = CriticalOutboxRepository(appContext)
    private val transportSelector = TransportSelector(appContext)
    private val helplineBridgeClient = SosHelplineBridgeApiClient()

    private val managerScope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    var victimName: String = "User"
    var myDeviceIdHex: String = "1122334455667788"
    var packetSenderDelegate: ((BitchatPacket) -> Unit)? = null

    private val _incomingSosAlerts = MutableSharedFlow<WomenSafetySosRecord>(replay = 10)
    val incomingSosAlerts: SharedFlow<WomenSafetySosRecord> = _incomingSosAlerts.asSharedFlow()

    private val _activeSosStatus = MutableStateFlow(OutboxStatus.QUEUED)
    val activeSosStatus: StateFlow<OutboxStatus> = _activeSosStatus.asStateFlow()

    private val _activePeersCount = MutableStateFlow(0)
    val activePeersCount: StateFlow<Int> = _activePeersCount.asStateFlow()

    private val activeLiveNodeIds = java.util.concurrent.ConcurrentHashMap<String, Long>()
    private val peerTtlMillis: Long = 30000L // BitChat 30s live node TTL

    fun registerLiveNodeHeartbeat(deviceIdHex: String) {
        activeLiveNodeIds[deviceIdHex] = System.currentTimeMillis()
    }

    fun getConnectedLiveNodesCount(): Int {
        val now = System.currentTimeMillis()
        activeLiveNodeIds.entries.removeIf { (now - it.value) > peerTtlMillis }
        return activeLiveNodeIds.size
    }

    private val receivedPeerAlerts = java.util.Collections.synchronizedList(mutableListOf<WomenSafetySosRecord>())

    fun getConnectedPeersCount(): Int {
        return getConnectedLiveNodesCount()
    }

    fun updateConnectedPeersCount(count: Int) {
        _activePeersCount.value = count
    }

    fun getReceivedSosRecords(): List<WomenSafetySosRecord> {
        return ArrayList(receivedPeerAlerts)
    }

    fun addReceivedSosRecord(sosRecord: WomenSafetySosRecord) {
        registerLiveNodeHeartbeat(sosRecord.victimDeviceId.toHexString())
        if (!receivedPeerAlerts.any { it.sosId.contentEquals(sosRecord.sosId) }) {
            receivedPeerAlerts.add(0, sosRecord)
        }
    }

    fun simulateIncomingPeerSos(
        victimName: String = "Ananya Sharma",
        latitude: Double = 21.1462,
        longitude: Double = 79.0890,
        batteryLevel: Int = 85,
        message: String = "HELP! Emergency distress signal from nearby guardian device!"
    ): WomenSafetySosRecord {
        val record = WomenSafetySosRecord(
            victimDeviceId = hexToBytes("A1B2C3D4E5F67890"),
            latitude = latitude,
            longitude = longitude,
            batteryLevel = batteryLevel,
            victimName = victimName,
            customMessage = message
        )
        addReceivedSosRecord(record)
        showSosNotification(record)
        managerScope.launch { _incomingSosAlerts.emit(record) }
        return record
    }

    init {
        createNotificationChannel()
        setupConnectivityListener()
    }

    /**
     * One-touch Emergency SOS trigger.
     * Broadcasts an emergency alert over the local BLE mesh immediately.
     */
    fun triggerEmergencySos(
        latitude: Double,
        longitude: Double,
        batteryLevel: Int = 100,
        customMessage: String = "EMERGENCY! Help required immediately!"
    ): WomenSafetySosRecord {
        val sosRecord = WomenSafetySosRecord(
            victimDeviceId = hexToBytes(myDeviceIdHex),
            latitude = latitude,
            longitude = longitude,
            batteryLevel = batteryLevel,
            victimName = victimName,
            customMessage = customMessage
        )

        val sosBinaryData = sosRecord.toBinaryPayload()
        val recordIdHex = sosRecord.sosId.toHexString()

        addReceivedSosRecord(sosRecord)

        // Create Critical Alert Packet with MAX CRITICAL priority
        val alertPayload = CriticalAlertPayload(
            recordId = sosRecord.sosId,
            alertType = CriticalAlertType.SOS_EMERGENCY,
            timestamp = sosRecord.timestamp,
            sequenceNum = 1u,
            originDeviceId = sosRecord.victimDeviceId,
            payloadData = sosBinaryData
        )

        val packet = BitchatPacket(
            version = 1u,
            type = MessageType.CRITICAL_ALERT.value,
            senderID = hexToBytes(myDeviceIdHex),
            recipientID = null, // Broadcast to EVERY device in range
            timestamp = sosRecord.timestamp,
            payload = alertPayload.toBinaryPayload(),
            ttl = 7u // Full 7 hops flood routing
        )

        // Save to persistent local database outbox & audit trail
        outboxRepository.saveAlert(alertPayload, MessagePriority.CRITICAL)
        _activeSosStatus.value = OutboxStatus.QUEUED

        // Broadcast over BLE Mesh
        packetSenderDelegate?.invoke(packet)
        _activeSosStatus.value = OutboxStatus.RELAYING

        Log.i(TAG, "🚨 EMERGENCY SOS BROADCAST SENT over BLE Mesh! (Lat: $latitude, Lng: $longitude)")

        // If this device is currently online, bridge to helpline immediately
        if (transportSelector.isOnline()) {
            managerScope.launch {
                val ack = helplineBridgeClient.bridgeSosToHelpline(sosRecord, myDeviceIdHex)
                if (ack != null) {
                    onDeliveryAckReceived(ack)
                }
            }
        }

        return sosRecord
    }

    /**
     * Handle incoming SOS packet received from a mesh peer.
     */
    fun handleIncomingPacket(packet: BitchatPacket) {
        if (packet.type == MessageType.CRITICAL_ALERT.value) {
            val alertPayload = CriticalAlertPayload.fromBinaryPayload(packet.payload) ?: return
            val sosRecord = WomenSafetySosRecord.fromBinaryPayload(alertPayload.payloadData) ?: return

            Log.w(TAG, "🚨 NEARBY SOS RECEIVED from ${sosRecord.victimName} (${sosRecord.latitude}, ${sosRecord.longitude})")
            addReceivedSosRecord(sosRecord)

            auditLogManager.logEvent(
                eventType = AuditEventType.ALERT_RELAYED,
                recordIdHex = sosRecord.sosId.toHexString(),
                peerIdHex = sosRecord.victimDeviceId.toHexString(),
                details = "Nearby SOS from ${sosRecord.victimName} at (${sosRecord.latitude}, ${sosRecord.longitude})"
            )

            // Trigger urgent system notification on nearby responder's phone
            showSosNotification(sosRecord)
            managerScope.launch { _incomingSosAlerts.emit(sosRecord) }

            // If this node has internet data, bridge to Helpline API!
            if (transportSelector.isOnline()) {
                managerScope.launch {
                    val ack = helplineBridgeClient.bridgeSosToHelpline(sosRecord, myDeviceIdHex)
                    if (ack != null) {
                        // Flood Delivery ACK back into local mesh to notify victim!
                        val ackPacket = BitchatPacket(
                            version = 1u,
                            type = MessageType.DELIVERY_ACK.value,
                            senderID = hexToBytes(myDeviceIdHex),
                            recipientID = sosRecord.victimDeviceId,
                            timestamp = System.currentTimeMillis().toULong(),
                            payload = ack.toBinaryPayload(),
                            ttl = 7u
                        )
                        packetSenderDelegate?.invoke(ackPacket)
                    }
                }
            }
        } else if (packet.type == MessageType.DELIVERY_ACK.value) {
            val ack = DeliveryAckPayload.fromBinaryPayload(packet.payload) ?: return
            onDeliveryAckReceived(ack)
        }
    }

    fun onDeliveryAckReceived(ack: DeliveryAckPayload) {
        val recordIdHex = ack.recordId.toHexString()
        Log.i(TAG, "✅ SOS DELIVERY ACK RECEIVED for $recordIdHex! (Bridged: ${ack.isBridged})")

        outboxRepository.markDelivered(recordIdHex, ack.ackTimestamp.toLong(), ack.bridgedByDeviceId?.toHexString())
        _activeSosStatus.value = OutboxStatus.DELIVERED
    }

    private fun setupConnectivityListener() {
        transportSelector.onConnectivityRestoredListener = {
            // When internet returns, flush any pending outbox records to helpline bridge
            managerScope.launch {
                val records = outboxRepository.getAllRecords()
                records.filter { it.status == OutboxStatus.QUEUED || it.status == OutboxStatus.RELAYING }.forEach { record ->
                    val payload = CriticalAlertPayload.fromBinaryPayload(record.payloadBytes)
                    if (payload != null) {
                        val sos = WomenSafetySosRecord.fromBinaryPayload(payload.payloadData)
                        if (sos != null) {
                            val ack = helplineBridgeClient.bridgeSosToHelpline(sos, myDeviceIdHex)
                            if (ack != null) {
                                onDeliveryAckReceived(ack)
                            }
                        }
                    }
                }
            }
        }
    }

    private fun showSosNotification(record: WomenSafetySosRecord) {
        val notificationManager = appContext.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val notification = NotificationCompat.Builder(appContext, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentTitle("🚨 EMERGENCY SOS: ${record.victimName}")
            .setContentText("Help required at GPS (${record.latitude}, ${record.longitude})")
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setAutoCancel(true)
            .build()

        notificationManager.notify(record.sosId.hashCode(), notification)
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Women's Safety Emergency SOS Alerts",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "High priority emergency alerts from nearby mesh peers"
                enableVibration(true)
            }
            val manager = appContext.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    private fun hexToBytes(hex: String): ByteArray {
        val result = ByteArray(8)
        var temp = hex
        var idx = 0
        while (temp.length >= 2 && idx < 8) {
            val byte = temp.substring(0, 2).toIntOrNull(16)?.toByte()
            if (byte != null) result[idx] = byte
            temp = temp.substring(2)
            idx++
        }
        return result
    }
}
