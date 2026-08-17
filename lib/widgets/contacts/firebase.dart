import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FirebaseMethods {
  static final FirebaseMethods _instance = FirebaseMethods._internal();
  factory FirebaseMethods() => _instance;
  FirebaseMethods._internal() {
    _loadLocalContacts();
  }

  static const String _storageKey = 'rakshasetu_trusted_contacts_list';
  final List<Map<String, dynamic>> _cachedContacts = [];
  final StreamController<List<Map<String, dynamic>>> _contactsStreamController =
      StreamController<List<Map<String, dynamic>>>.broadcast();

  Stream<List<Map<String, dynamic>>> get localContactsStream =>
      _contactsStreamController.stream;

  List<Map<String, dynamic>> get currentContacts =>
      List.unmodifiable(_cachedContacts);

  String _cleanPhone(String? phone) {
    if (phone == null) return '';
    return phone.replaceAll(RegExp(r'[^0-9]'), '');
  }

  String _cleanName(String? name) {
    if (name == null) return '';
    return name.trim().toLowerCase();
  }

  List<Map<String, dynamic>> _deduplicateList(List<Map<String, dynamic>> list) {
    final Map<String, Map<String, dynamic>> uniqueByPhone = {};
    final Map<String, Map<String, dynamic>> uniqueByName = {};
    final List<Map<String, dynamic>> result = [];

    for (final contact in list) {
      final phone = _cleanPhone(contact['Number']?.toString());
      final name = _cleanName(contact['Name']?.toString());

      if (phone.isNotEmpty && uniqueByPhone.containsKey(phone)) {
        continue;
      }
      if (name.isNotEmpty && uniqueByName.containsKey(name)) {
        continue;
      }

      if (phone.isNotEmpty) uniqueByPhone[phone] = contact;
      if (name.isNotEmpty) uniqueByName[name] = contact;
      result.add(contact);
    }
    return result;
  }

  Future<void> _loadLocalContacts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey) ?? prefs.getString('bsafe_trusted_contacts_list');
      if (raw != null && raw.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(raw);
        final List<Map<String, dynamic>> loaded = [];
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            loaded.add(Map<String, dynamic>.from(item));
          }
        }
        _cachedContacts.clear();
        _cachedContacts.addAll(_deduplicateList(loaded));
        _contactsStreamController.add(List.from(_cachedContacts));
      }
    } catch (e) {
      debugPrint('[ContactsService] Error loading local contacts: $e');
    }
  }

  Future<void> _saveLocalContacts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(_cachedContacts));
      _contactsStreamController.add(List.from(_cachedContacts));
    } catch (e) {
      debugPrint('[ContactsService] Error saving local contacts: $e');
    }
  }

  //* Create / Add Contact (with Strict Deduplication)
  Future<void> addContact(
      Map<String, dynamic> contactDetails, String id) async {
    final formatted = Map<String, dynamic>.from(contactDetails);
    formatted['id'] = id;

    final newPhone = _cleanPhone(formatted['Number']?.toString());
    final newName = _cleanName(formatted['Name']?.toString());

    // Check if a contact with the same phone or same name already exists
    final existingIndex = _cachedContacts.indexWhere((c) {
      final cPhone = _cleanPhone(c['Number']?.toString());
      final cName = _cleanName(c['Name']?.toString());
      return (newPhone.isNotEmpty && cPhone.isNotEmpty && newPhone == cPhone) ||
          (newName.isNotEmpty && cName.isNotEmpty && newName == cName) ||
          c['id'] == id;
    });

    if (existingIndex >= 0) {
      // Update existing record preserving its original id
      formatted['id'] = _cachedContacts[existingIndex]['id'] ?? id;
      _cachedContacts[existingIndex] = formatted;
    } else {
      _cachedContacts.add(formatted);
    }

    // Save deduplicated local contacts
    final deduped = _deduplicateList(_cachedContacts);
    _cachedContacts.clear();
    _cachedContacts.addAll(deduped);
    await _saveLocalContacts();

    // Sync to Firestore
    try {
      final targetId = formatted['id']?.toString() ?? id;
      await FirebaseFirestore.instance
          .collection('Contacts')
          .doc(targetId)
          .set(formatted);
    } catch (e) {
      debugPrint('[ContactsService] Firestore sync skipped: $e');
    }
  }

  //* Read Contacts
  Future<Stream<QuerySnapshot>> getContactList() async {
    try {
      return FirebaseFirestore.instance.collection('Contacts').snapshots();
    } catch (e) {
      debugPrint('[ContactsService] Firestore stream error: $e');
      return const Stream.empty();
    }
  }

  Future<List<Map<String, dynamic>>> getLocalContacts() async {
    if (_cachedContacts.isEmpty) {
      await _loadLocalContacts();
    }
    return _deduplicateList(_cachedContacts);
  }

  //* Delete Contact
  Future<void> deleteContact(String id) async {
    _cachedContacts.removeWhere((c) => c['id'] == id);
    await _saveLocalContacts();

    try {
      await FirebaseFirestore.instance.collection('Contacts').doc(id).delete();
    } catch (e) {
      debugPrint('[ContactsService] Firestore delete skipped: $e');
    }
  }
}
