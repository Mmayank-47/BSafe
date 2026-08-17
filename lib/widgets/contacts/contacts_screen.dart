import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:random_string/random_string.dart';
import 'package:safe/components/custom_button.dart';
import 'package:safe/theme/app_theme.dart';
import 'package:safe/widgets/contacts/firebase.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final FirebaseMethods _firebaseMethods = FirebaseMethods();
  List<Map<String, dynamic>> _contactsList = [];
  StreamSubscription? _localSub;
  StreamSubscription? _firestoreSub;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  List<Map<String, dynamic>> _deduplicate(List<Map<String, dynamic>> list) {
    final Map<String, Map<String, dynamic>> byPhone = {};
    final Map<String, Map<String, dynamic>> byName = {};
    final List<Map<String, dynamic>> res = [];

    for (final c in list) {
      final phone = (c['Number'] ?? '').toString().replaceAll(RegExp(r'[^0-9]'), '');
      final name = (c['Name'] ?? '').toString().trim().toLowerCase();

      if (phone.isNotEmpty && byPhone.containsKey(phone)) continue;
      if (name.isNotEmpty && byName.containsKey(name)) continue;

      if (phone.isNotEmpty) byPhone[phone] = c;
      if (name.isNotEmpty) byName[name] = c;
      res.add(c);
    }
    return res;
  }

  Future<void> _loadContacts() async {
    // 1. Load immediate local contacts (includes contacts from Onboarding Step 2)
    final local = await _firebaseMethods.getLocalContacts();
    if (mounted) {
      setState(() {
        _contactsList = _deduplicate(local);
        _isLoading = false;
      });
    }

    // 2. Subscribe to local stream
    _localSub = _firebaseMethods.localContactsStream.listen((contacts) {
      if (mounted) {
        setState(() {
          _contactsList = _deduplicate(contacts);
        });
      }
    });

    // 3. Subscribe to Firestore stream if available
    try {
      final fsStream = await _firebaseMethods.getContactList();
      _firestoreSub = fsStream.listen((snapshot) {
        if (snapshot.docs.isNotEmpty) {
          final List<Map<String, dynamic>> fromFs = [];
          for (final doc in snapshot.docs) {
            final data = doc.data() as Map<String, dynamic>?;
            if (data != null) {
              final item = Map<String, dynamic>.from(data);
              item['id'] = doc.id;
              fromFs.add(item);
            }
          }
          if (fromFs.isNotEmpty && mounted) {
            setState(() {
              _contactsList = _deduplicate(fromFs);
            });
          }
        }
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _localSub?.cancel();
    _firestoreSub?.cancel();
    super.dispose();
  }

  void uploadContact() {
    final nameController = TextEditingController();
    final numberController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
          top: 24,
          left: 24,
          right: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add Trusted Contact',
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                hintText: 'Contact Name',
                prefixIcon: const Icon(Icons.person_rounded),
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: numberController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: 'Phone Number',
                prefixIcon: const Icon(Icons.phone_rounded),
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),
            CustomButton(
              text: "Save Contact",
              onPressed: () async {
                if (nameController.text.isEmpty || numberController.text.isEmpty) {
                  Fluttertoast.showToast(msg: "Please fill all details");
                  return;
                }
                String id = randomAlphaNumeric(9);
                Map<String, dynamic> details = {
                  "id": id,
                  "Name": nameController.text,
                  "Number": numberController.text,
                };

                await _firebaseMethods.addContact(details, id).then((value) {
                  Fluttertoast.showToast(msg: "Contact Added Successfully!");
                });
                if (ctx.mounted) {
                  Navigator.of(ctx).pop();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _makeCall(String number) async {
    final Uri url = Uri.parse("tel:$number");
    try {
      await launchUrl(url);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Trusted Contacts',
                        style: GoogleFonts.outfit(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textDark,
                        ),
                      ),
                      Text(
                        'Emergency Alert Recipients',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          color: AppTheme.primaryPurple,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: uploadContact,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: AppTheme.glassCardDecoration(borderRadius: 16),
                      child: const Icon(
                        Icons.person_add_rounded,
                        color: AppTheme.primaryPurple,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _contactsList.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.contacts_rounded,
                                  size: 64,
                                  color: AppTheme.textMuted,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No trusted contacts added yet.',
                                  style: GoogleFonts.outfit(
                                    fontSize: 16,
                                    color: AppTheme.textMuted,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: uploadContact,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryPurple,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  icon: const Icon(Icons.add, color: Colors.white),
                                  label: const Text('Add Contact', style: TextStyle(color: Colors.white)),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            physics: const BouncingScrollPhysics(),
                            itemCount: _contactsList.length,
                            itemBuilder: (ctx, index) {
                              final contact = _contactsList[index];
                              final id = contact['id'] ?? index.toString();
                              final name = contact['Name'] ?? 'Contact';
                              final number = contact['Number'] ?? '';
                              final relationship = contact['Relationship'] ?? 'Emergency Contact';

                              return Dismissible(
                                key: Key(id),
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  margin: const EdgeInsets.symmetric(vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppTheme.accentRose,
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 24),
                                  child: const Icon(
                                    Icons.delete_rounded,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
                                onDismissed: (direction) async {
                                  await _firebaseMethods.deleteContact(id);
                                  Fluttertoast.showToast(msg: "Contact Deleted");
                                },
                                child: Container(
                                  margin: const EdgeInsets.symmetric(vertical: 6),
                                  padding: const EdgeInsets.all(12),
                                  decoration: AppTheme.glassCardDecoration(borderRadius: 24),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      radius: 24,
                                      backgroundColor: AppTheme.primaryPurple.withValues(alpha: 0.15),
                                      child: Text(
                                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                                        style: GoogleFonts.outfit(
                                          color: AppTheme.primaryPurple,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      name,
                                      style: GoogleFonts.outfit(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.textDark,
                                      ),
                                    ),
                                    subtitle: Text(
                                      '$number • $relationship',
                                      style: GoogleFonts.outfit(
                                        fontSize: 13,
                                        color: AppTheme.textMuted,
                                      ),
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.phone_rounded, color: AppTheme.accentMint),
                                      onPressed: () => _makeCall(number),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
