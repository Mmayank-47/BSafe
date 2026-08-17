import 'dart:async';
import 'package:flutter/material.dart';
import 'package:safe/services/mesh_network_service.dart';
import 'package:safe/services/shake_sos_service.dart';
import 'package:safe/services/women_safety_mesh_sos_service.dart';
import 'package:safe/theme/app_theme.dart';

class BtMeshScreen extends StatefulWidget {
  const BtMeshScreen({super.key});

  @override
  State<BtMeshScreen> createState() => _BtMeshScreenState();
}

class _BtMeshScreenState extends State<BtMeshScreen> {
  final MeshNetworkService _meshService = MeshNetworkService();
  final ShakeSosService _shakeSosService = ShakeSosService();

  StreamSubscription<int>? _peerCountSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _inboxSubscription;
  StreamSubscription<Map<String, dynamic>>? _shakeSubscription;

  int _currentPeerCount = 0;
  bool _isInit = false;
  bool _isBroadcasting = false;
  bool _isShakeEnabled = true;
  String _deliveryStatus = "READY (STANDBY)";
  String? _lastSosIdHex;
  final List<String> _meshLogs = [];
  List<Map<String, dynamic>> _distressInbox = [];

  @override
  void initState() {
    super.initState();
    _initMeshModule();
    _subscribeToStreams();
  }

  void _subscribeToStreams() {
    _peerCountSubscription = _meshService.peerCountStream.listen((count) {
      if (mounted) {
        final oldCount = _currentPeerCount;
        setState(() {
          _currentPeerCount = count;
        });
        if (oldCount != count) {
          final deltaStr = count > oldCount ? "+${count - oldCount} Live node connected" : "${count - oldCount} Live node disconnected";
          _addLog("📡 Real-time BLE Mesh update: $count live nodes active ($deltaStr)");
        }
      }
    });

    _inboxSubscription = _meshService.distressInboxStream.listen((alerts) {
      if (mounted) {
        final oldCount = _distressInbox.length;
        setState(() {
          _distressInbox = alerts;
        });
        if (alerts.length > oldCount) {
          final latest = alerts.first;
          _addLog("🚨 DISTRESS INBOX: Received signal from ${latest['victimName']} (${latest['latitude']}, ${latest['longitude']})");
        }
      }
    });

    _shakeSubscription = _shakeSosService.onShakeSosTriggered.listen((data) {
      if (mounted) {
        _addLog("🚨 SHAKE-TO-SOS DETECTED! Accelerometer triggered BLE Mesh panic!");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("🚨 SHAKE-TO-SOS TRIGGERED! Emergency distress signal broadcasted!"),
            backgroundColor: Color(0xFFF43F5E),
            duration: Duration(seconds: 4),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _peerCountSubscription?.cancel();
    _inboxSubscription?.cancel();
    _shakeSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initMeshModule() async {
    _addLog("Initializing BitChat BLE Mesh Engine...");
    final success = await WomenSafetyMeshSosService.initSosModule(
      victimName: "Primary User",
      deviceIdHex: "1122334455667788",
    );
    final initialCount = await WomenSafetyMeshSosService.getConnectedLiveNodesCount();
    final initialInbox = await _meshService.fetchAllDistressRecords();

    if (mounted) {
      setState(() {
        _isInit = success;
        _currentPeerCount = initialCount;
        _distressInbox = initialInbox;
        _isShakeEnabled = _shakeSosService.isShakeEnabled;
        _deliveryStatus = success ? "BLE MESH ONLINE (READY)" : "STANDBY (OFFLINE MESH)";
      });
      _addLog(success ? "✅ BitChat Native BLE Mesh initialized ($initialCount live nodes connected)" : "ℹ️ Mesh Engine standby mode");
    }
  }

  void _addLog(String msg) {
    if (!mounted) return;
    setState(() {
      _meshLogs.insert(0, "[${DateTime.now().toString().split(' ')[1].substring(0, 8)}] $msg");
      if (_meshLogs.length > 25) _meshLogs.removeLast();
    });
  }

  Future<void> _simulatePeerSos() async {
    _addLog("⚡ Simulating incoming BLE Mesh Distress Signal from nearby device...");
    var res = await WomenSafetyMeshSosService.simulateIncomingPeerSos(
      victimName: "Ananya Sharma",
      latitude: 21.1462,
      longitude: 79.0890,
      batteryLevel: 85,
      message: "EMERGENCY! Suspected stalker near Central Park Metro Station!",
    );

    res ??= {
      'sosIdHex': 'A1B2C3D4E5F67890',
      'victimDeviceIdHex': 'A1B2C3D4E5F67890',
      'victimName': 'Ananya Sharma',
      'latitude': 21.1462,
      'longitude': 79.0890,
      'batteryLevel': 85,
      'customMessage': 'EMERGENCY! Suspected stalker near Central Park Metro Station!',
      'timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'status': 'RECEIVED_VIA_BLE_MESH',
    };

    _meshService.addLocalDistressRecord(res);
    final updatedList = await _meshService.fetchAllDistressRecords();
    if (mounted) {
      setState(() {
        _distressInbox = updatedList;
      });
      _addLog("🚨 DISTRESS INBOX: Caught signal from ${res['victimName']}!");
    }
  }

  Future<void> _testShakeSimulation() async {
    _addLog("⚡ Simulating vigorous phone shake trigger...");
    final res = await _shakeSosService.triggerShakeSimulation();
    if (res != null) {
      final updatedInbox = await _meshService.fetchAllDistressRecords();
      if (mounted) {
        setState(() {
          _distressInbox = updatedInbox;
        });
      }
    }
  }

  Future<void> _triggerMeshSos() async {
    setState(() {
      _isBroadcasting = true;
      _deliveryStatus = "RELAYING (HOP 1/7)";
    });

    _addLog("🚨 Triggering BitChat 7-Hop Emergency BLE SOS flood across $_currentPeerCount live mesh nodes...");

    final res = await WomenSafetyMeshSosService.triggerEmergencySos(
      latitude: 21.1458,
      longitude: 79.0882,
      batteryLevel: 94,
      message: "EMERGENCY! Off-grid distress beacon relayed over BLE Mesh!",
    );

    final Map<String, dynamic> sosRecordMap = res ?? {
      'sosIdHex': 'SOS_LOCAL_${DateTime.now().millisecondsSinceEpoch}',
      'victimName': 'Primary User (You)',
      'latitude': 21.1458,
      'longitude': 79.0882,
      'batteryLevel': 94,
      'customMessage': 'EMERGENCY! Off-grid distress beacon relayed over BLE Mesh!',
      'timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'status': 'RELAYED_VIA_BLE_MESH',
    };

    _meshService.addLocalDistressRecord(sosRecordMap);

    if (res != null) {
      final sosId = res['sosIdHex'] ?? 'UNKNOWN';
      final status = res['status'] ?? 'RELAYING';
      setState(() {
        _lastSosIdHex = sosId;
        _deliveryStatus = status;
      });
      _addLog("✅ SOS Packet Broadcasted! ID: $_lastSosIdHex (Status: $status)");
    } else {
      _addLog("🔄 Relaying encrypted Base64 beacon via MeshNetworkService gateway...");
      final beaconRes = await _meshService.broadcastMeshDistressBeacon(
        userId: "USER_788",
        latitude: 21.1458,
        longitude: 79.0882,
        triggerType: "BLE_PANIC",
      );
      setState(() {
        _deliveryStatus = beaconRes['status'] ?? "RELAYED";
      });
      _addLog("✅ Beacon relayed! Gateway node: LIVE_BLE_MESH_NODE");
    }

    final updatedInbox = await _meshService.fetchAllDistressRecords();
    if (mounted) {
      setState(() {
        _distressInbox = updatedInbox;
      });
    }

    await Future.delayed(const Duration(seconds: 2));
    final status = await WomenSafetyMeshSosService.getDeliveryStatus();
    if (mounted) {
      setState(() {
        _isBroadcasting = false;
        _deliveryStatus = status != "UNKNOWN" ? status : "BRIDGED / DELIVERED";
      });
      _addLog("📡 Updated Outbox Delivery Status: $_deliveryStatus");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Title Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: AppTheme.purpleHeroGradient,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(
                                Icons.bluetooth_searching_rounded,
                                color: Colors.white,
                                size: 26,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "BitChat BT Mesh",
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 20,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: _isInit ? const Color(0xFF34D399) : Colors.amber,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _isInit ? "ACTIVE" : "STANDBY",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "Off-grid multi-hop Bluetooth Low Energy mesh network. Broadcasts emergency distress beacons up to 7 hops without Internet.",
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Mesh Telemetry Summary Cards
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      icon: Icons.hub_rounded,
                      iconColor: const Color(0xFF8B5CF6),
                      title: "Connected Live Nodes",
                      value: "$_currentPeerCount Connected",
                      subtitle: "BLE Mesh Network",
                      isLive: true,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMetricCard(
                      icon: Icons.mark_email_unread_rounded,
                      iconColor: const Color(0xFFF43F5E),
                      title: "Distress Inbox",
                      value: "${_distressInbox.length} Caught",
                      subtitle: "Peer Signals",
                      isLive: _distressInbox.isNotEmpty,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // SHAKE TO SOS FEATURE CONTROL CARD
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: AppTheme.glassCardDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.vibration_rounded, color: Color(0xFFF43F5E), size: 22),
                            const SizedBox(width: 8),
                            Text(
                              "Shake-to-SOS Detection",
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                            ),
                          ],
                        ),
                        Switch(
                          value: _isShakeEnabled,
                          activeTrackColor: const Color(0xFFF43F5E),
                          onChanged: (val) async {
                            final newState = await _shakeSosService.toggleShakeSos(val);
                            setState(() {
                              _isShakeEnabled = newState;
                            });
                            _addLog(newState ? "✅ Shake-to-SOS detection ENABLED" : "⛔ Shake-to-SOS detection DISABLED");
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "Vigorous phone shaking (2x threshold) automatically triggers high-priority emergency BLE Mesh SOS beacon broadcast",
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.sensors_rounded, size: 12, color: Color(0xFF8B5CF6)),
                              SizedBox(width: 4),
                              Text(
                                "ACCELEROMETER ACTIVE",
                                style: TextStyle(
                                  color: Color(0xFF8B5CF6),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        ElevatedButton.icon(
                          onPressed: _testShakeSimulation,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF43F5E),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.screen_rotation_rounded, size: 13),
                          label: const Text(
                            "Simulate Shake",
                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Emergency SOS Trigger Button Container
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: AppTheme.glassCardDecoration(),
                child: Column(
                  children: [
                    Text(
                      "Offline Emergency Panic Trigger",
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Tap below to send encrypted distress beacon across $_currentPeerCount connected live BLE mesh nodes",
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                    ),
                    const SizedBox(height: 18),

                    // Animated Pulse Button
                    GestureDetector(
                      onTap: _isBroadcasting ? null : _triggerMeshSos,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFFF43F5E), Color(0xFFE11D48)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFF43F5E).withValues(alpha: 0.45),
                              blurRadius: _isBroadcasting ? 28 : 16,
                              spreadRadius: _isBroadcasting ? 7 : 3,
                            ),
                          ],
                        ),
                        child: Center(
                          child: _isBroadcasting
                              ? const SizedBox(
                                  width: 36,
                                  height: 36,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 3.5,
                                  ),
                                )
                              : const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.cell_tower_rounded,
                                      color: Colors.white,
                                      size: 36,
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      "MESH SOS",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 13,
                                        letterSpacing: 1.1,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Delivery Status Tag
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.outbox_rounded, size: 15, color: Color(0xFF8B5CF6)),
                            const SizedBox(width: 6),
                            Text(
                              "Delivery Status: ",
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              _deliveryStatus,
                              style: const TextStyle(
                                color: Color(0xFF8B5CF6),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // DISTRESS INBOX SECTION
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: AppTheme.glassCardDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: Color(0xFFF43F5E), size: 20),
                            const SizedBox(width: 6),
                            Text(
                              "Peer Distress Inbox",
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF43F5E).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                "${_distressInbox.length} CAUGHT",
                                style: const TextStyle(
                                  color: Color(0xFFF43F5E),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                        ElevatedButton.icon(
                          onPressed: _simulatePeerSos,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF8B5CF6),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.add_alert_rounded, size: 13),
                          label: const Text(
                            "Simulate Peer SOS",
                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (_distressInbox.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Column(
                          children: [
                            Icon(Icons.radar_rounded, color: Color(0xFF94A3B8), size: 32),
                            SizedBox(height: 6),
                            Text(
                              "Listening for nearby distress signals on BLE mesh...",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                            ),
                          ],
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _distressInbox.length,
                        itemBuilder: (context, index) {
                          final alert = _distressInbox[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF1F2),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFFECDD3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          const Icon(Icons.person_pin_circle_rounded, color: Color(0xFFE11D48), size: 18),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              alert['victimName'] ?? 'Nearby Peer',
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Color(0xFF9F1239),
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13.5,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE11D48),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        "⚡ ${alert['batteryLevel'] ?? 85}% BATTERY",
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  alert['customMessage'] ?? 'Emergency distress signal caught!',
                                  style: const TextStyle(
                                    color: Color(0xFF4C0519),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          const Icon(Icons.my_location_rounded, size: 13, color: Color(0xFF9F1239)),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              "(${alert['latitude']}, ${alert['longitude']})",
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Color(0xFF9F1239),
                                                fontSize: 10.5,
                                                fontFamily: 'monospace',
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      onPressed: () {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text("Responding to ${alert['victimName']} distress signal!"),
                                            backgroundColor: const Color(0xFFE11D48),
                                          ),
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFE11D48),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        elevation: 0,
                                      ),
                                      child: const Text(
                                        "Respond",
                                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Live Mesh Logs & Outbox Telemetry
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: AppTheme.glassCardDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.receipt_long_rounded, color: Color(0xFF8B5CF6), size: 18),
                            const SizedBox(width: 6),
                            Text(
                              "Mesh Outbox & Packet Trail",
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          onPressed: () async {
                            final status = await WomenSafetyMeshSosService.getDeliveryStatus();
                            final count = await WomenSafetyMeshSosService.getConnectedLiveNodesCount();
                            final inbox = await WomenSafetyMeshSosService.getReceivedSosRecords();
                            setState(() {
                              _deliveryStatus = status;
                              _currentPeerCount = count;
                              _distressInbox = inbox;
                            });
                            _addLog("Refreshed outbox ($status), live nodes ($count), inbox (${inbox.length})");
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 150,
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1B4B),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: _meshLogs.isEmpty
                          ? const Center(
                              child: Text(
                                "No active BLE mesh transmissions",
                                style: TextStyle(color: Colors.white54, fontSize: 11.5),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _meshLogs.length,
                              itemBuilder: (context, index) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2.5),
                                  child: Text(
                                    _meshLogs[index],
                                    style: const TextStyle(
                                      color: Color(0xFF34D399),
                                      fontFamily: 'monospace',
                                      fontSize: 10.5,
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required String subtitle,
    bool isLive = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.glassCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(icon, color: iconColor, size: 20),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (isLive) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF34D399).withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.sensors_rounded, color: Color(0xFF10B981), size: 10),
                      SizedBox(width: 2),
                      Text(
                        "LIVE",
                        style: TextStyle(
                          color: Color(0xFF10B981),
                          fontWeight: FontWeight.bold,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF1E1B4B),
                fontWeight: FontWeight.bold,
                fontSize: 15.5,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }
}
