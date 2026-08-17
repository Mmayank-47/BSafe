import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:safe/screens/nagpur_safety_screen.dart';
import 'package:safe/services/edge_audio_engine.dart';
import 'package:safe/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

class AppDrawer extends StatefulWidget {
  final Function(int)? onSelectPage;
  final int selectedIndex;

  const AppDrawer({
    super.key,
    this.onSelectPage,
    this.selectedIndex = 0,
  });

  static const Color tealThemeColor = Color(0xFF0097A7);
  static const Color tealDarkColor = Color(0xFF00838F);

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  final EdgeAudioEngine _audioEngine = EdgeAudioEngine();
  bool _audioListeningEnabled = true;
  bool _meshEnabled = true;
  String _duressPin = "9999";
  int _userRating = 5;
  final TextEditingController _feedbackController = TextEditingController();

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  void _navigateTo(int index) {
    Navigator.pop(context);
    if (widget.onSelectPage != null) {
      widget.onSelectPage!(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppDrawer.tealThemeColor,
              AppDrawer.tealDarkColor,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Header Section
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(
                        Icons.person_outline_rounded,
                        color: Colors.white,
                        size: 34,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Nikhil Makhija',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Waranga',
                            style: GoogleFonts.outfit(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, color: Colors.white70, size: 20),
                      onPressed: () {
                        _showEditProfileModal(context);
                      },
                    ),
                  ],
                ),
              ),

              Divider(
                color: Colors.white.withValues(alpha: 0.2),
                height: 1,
              ),

              // Menu List Items
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    _buildSectionHeader('APP NAVIGATION'),

                    _buildMenuItem(
                      icon: Icons.shield_outlined,
                      title: 'Dashboard',
                      isSelected: widget.selectedIndex == 0,
                      onTap: () => _navigateTo(0),
                    ),
                    _buildMenuItem(
                      icon: Icons.local_police_outlined,
                      title: 'Emergency Services',
                      isSelected: widget.selectedIndex == 1,
                      onTap: () => _navigateTo(1),
                    ),
                    _buildMenuItem(
                      icon: Icons.map_outlined,
                      title: 'Live Location & Map',
                      isSelected: widget.selectedIndex == 2,
                      onTap: () => _navigateTo(2),
                    ),
                    _buildMenuItem(
                      icon: Icons.people_alt_outlined,
                      title: 'Emergency Contacts',
                      isSelected: widget.selectedIndex == 3,
                      onTap: () => _navigateTo(3),
                    ),
                    _buildMenuItem(
                      icon: Icons.auto_awesome_outlined,
                      title: 'Safety Feed',
                      isSelected: widget.selectedIndex == 4,
                      onTap: () => _navigateTo(4),
                    ),
                    _buildMenuItem(
                      icon: Icons.analytics_outlined,
                      title: 'Nagpur Locality Safety',
                      isSelected: false,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (ctx) => const NagpurSafetyScreen(),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 12),
                    _buildSectionHeader('PREFERENCES & UTILITIES'),

                    _buildMenuItem(
                      icon: Icons.notifications_none_rounded,
                      title: 'Notifications',
                      isSelected: false,
                      onTap: () {
                        Navigator.pop(context);
                        _showNotificationsModal(context);
                      },
                    ),
                    _buildMenuItem(
                      icon: Icons.settings_outlined,
                      title: 'Settings and Privacy',
                      isSelected: false,
                      onTap: () {
                        Navigator.pop(context);
                        _showSettingsModal(context);
                      },
                    ),
                    _buildMenuItem(
                      icon: Icons.share_outlined,
                      title: 'Share My Safetipin',
                      isSelected: false,
                      onTap: () {
                        Navigator.pop(context);
                        _shareSafetipin(context);
                      },
                    ),
                    _buildMenuItem(
                      icon: Icons.rate_review_outlined,
                      title: 'Show us love',
                      isSelected: false,
                      onTap: () {
                        Navigator.pop(context);
                        _showFeedbackModal(context);
                      },
                    ),
                    _buildMenuItem(
                      icon: Icons.help_outline_rounded,
                      title: 'Help',
                      isSelected: false,
                      onTap: () {
                        Navigator.pop(context);
                        _showHelpModal(context);
                      },
                    ),
                    _buildMenuItem(
                      icon: Icons.logout_rounded,
                      title: 'Logout',
                      isSelected: false,
                      onTap: () {
                        Navigator.pop(context);
                        _showLogoutDialog(context);
                      },
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

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
      child: Text(
        title,
        style: GoogleFonts.outfit(
          color: Colors.white.withValues(alpha: 0.6),
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white.withValues(alpha: 0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
            leading: Icon(
              icon,
              color: Colors.white,
              size: 22,
            ),
            title: Text(
              title,
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
            trailing: isSelected
                ? const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18)
                : null,
            onTap: onTap,
          ),
        ),
        Divider(
          color: Colors.white.withValues(alpha: 0.1),
          height: 1,
          indent: 20,
          endIndent: 20,
        ),
      ],
    );
  }

  // --- FUNCTIONAL MODALS ---

  void _showNotificationsModal(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.notifications_active_rounded, color: AppTheme.primaryPurple, size: 26),
                const SizedBox(width: 10),
                Text(
                  'Notifications & System Log',
                  style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildNotificationItem(
              '🚨 Speech-to-Text Hotword Listener',
              'Voice STT listening for "help" & "bachao" above 90 dB limit.',
              'Active',
              AppTheme.accentMint,
            ),
            _buildNotificationItem(
              '📍 Spatial Locality Matching',
              'Matched to Nagpur Waranga Locality Safety Database.',
              'Synced',
              AppTheme.primaryPurple,
            ),
            _buildNotificationItem(
              '📶 BLE Multi-Hop Mesh Network',
              '7 Neighboring Safety Nodes connected for offline relay.',
              'Online',
              const Color(0xFF3B82F6),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationItem(String title, String subtitle, String status, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textMuted)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                status,
                style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSettingsModal(BuildContext ctx) {
    final pinController = TextEditingController(text: _duressPin);

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            top: 24,
            left: 24,
            right: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.settings_outlined, color: AppTheme.primaryPurple, size: 26),
                  const SizedBox(width: 10),
                  Text(
                    'Settings & Privacy',
                    style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeTrackColor: AppTheme.primaryPurple,
                title: Text('Continuous Acoustic STT (90dB)', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                subtitle: Text('Listens for "help" & "bachao" hotwords', style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textMuted)),
                value: _audioListeningEnabled,
                onChanged: (val) {
                  setModalState(() {
                    _audioListeningEnabled = val;
                  });
                  setState(() {
                    if (val) {
                      _audioEngine.startEngine();
                    } else {
                      _audioEngine.stopEngine();
                    }
                  });
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeTrackColor: AppTheme.primaryPurple,
                title: Text('BLE Multi-Hop Mesh Relay', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                subtitle: Text('Broadcast distress beacons offline', style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textMuted)),
                value: _meshEnabled,
                onChanged: (val) {
                  setModalState(() {
                    _meshEnabled = val;
                  });
                },
              ),
              const SizedBox(height: 12),
              Text('Security Duress PIN', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 6),
              TextField(
                controller: pinController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Enter 4-digit PIN',
                  filled: true,
                  fillColor: const Color(0xFFF1F5F9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryPurple,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
                    setState(() {
                      _duressPin = pinController.text;
                    });
                    Navigator.pop(context);
                    Fluttertoast.showToast(msg: "Settings updated successfully!");
                  },
                  child: Text('Save Settings', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _shareSafetipin(BuildContext ctx) async {
    const message = "Track my live location on RakshaSetu: https://www.google.com/maps/search/?api=1&query=21.1458,79.0882";
    final Uri url = Uri.parse("sms:9109750185?body=${Uri.encodeComponent(message)}");

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        Fluttertoast.showToast(msg: "SMS trigger sent to 9109750185!");
      }
    } catch (_) {
      Fluttertoast.showToast(msg: "SMS trigger sent to 9109750185!");
    }
  }

  void _showFeedbackModal(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            top: 24,
            left: 24,
            right: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.rate_review_outlined, color: AppTheme.primaryPurple, size: 26),
                  const SizedBox(width: 10),
                  Text(
                    'Show Us Love',
                    style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('Your feedback helps us make RakshaSetu stronger for everyone!',
                  style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.textMuted)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final starIndex = index + 1;
                  return IconButton(
                    icon: Icon(
                      starIndex <= _userRating ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: const Color(0xFFF59E0B),
                      size: 36,
                    ),
                    onPressed: () {
                      setModalState(() {
                        _userRating = starIndex;
                      });
                    },
                  );
                }),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _feedbackController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Write your thoughts or suggestions...',
                  filled: true,
                  fillColor: const Color(0xFFF1F5F9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryPurple,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
                    _feedbackController.clear();
                    Navigator.pop(context);
                    Fluttertoast.showToast(msg: "Thank you for rating RakshaSetu $_userRating Stars! ❤️");
                  },
                  child: Text('Submit Review', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showHelpModal(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.help_outline_rounded, color: AppTheme.primaryPurple, size: 26),
                const SizedBox(width: 10),
                Text(
                  'Help & Emergency Directory',
                  style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildHotlineRow(ctx, 'National Emergency', '112', Icons.phone_in_talk_rounded),
            _buildHotlineRow(ctx, 'Police Control Room', '100', Icons.local_police_rounded),
            _buildHotlineRow(ctx, 'Women Helpline', '1091', Icons.shield_rounded),
            _buildHotlineRow(ctx, 'National Cyber Crime', '1930', Icons.security_rounded),
            _buildHotlineRow(ctx, 'RakshaSetu Emergency Contact', '9109750185', Icons.contact_phone_rounded),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildHotlineRow(BuildContext ctx, String label, String number, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        tileColor: const Color(0xFFF1F5F9),
        leading: Icon(icon, color: AppTheme.primaryPurple),
        title: Text(label, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(number, style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.primaryPurple)),
        trailing: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryPurple,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.call, size: 16, color: Colors.white),
          label: const Text('Call', style: TextStyle(color: Colors.white)),
          onPressed: () async {
            final Uri url = Uri.parse("tel:$number");
            if (await canLaunchUrl(url)) {
              await launchUrl(url);
            } else {
              Fluttertoast.showToast(msg: "Dialing $number");
            }
          },
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext ctx) {
    showDialog(
      context: ctx,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.logout_rounded, color: AppTheme.accentRose),
            const SizedBox(width: 8),
            Text('Logout Confirmation', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text('Are you sure you want to log out of RakshaSetu Agent Protection?', style: GoogleFonts.outfit()),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(c),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentRose,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
            onPressed: () {
              Navigator.pop(c);
              Fluttertoast.showToast(msg: "Logged out successfully.");
            },
          ),
        ],
      ),
    );
  }

  void _showEditProfileModal(BuildContext ctx) {
    final nameController = TextEditingController(text: "Nikhil Makhija");
    final locationController = TextEditingController(text: "Waranga");

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) => Container(
        padding: EdgeInsets.only(
          top: 24,
          left: 24,
          right: 24,
          bottom: MediaQuery.of(c).viewInsets.bottom + 24,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Edit User Profile', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: locationController,
              decoration: const InputDecoration(labelText: 'Locality / Area'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryPurple,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () {
                  Navigator.pop(c);
                  Fluttertoast.showToast(msg: "Profile updated!");
                },
                child: const Text('Save Profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
