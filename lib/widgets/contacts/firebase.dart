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

  static const String _storageKey = 'bsafe_trusted_contacts_list';
  final List<Map<String, dynamic>> _cachedContacts = [];
  final StreamController<List<Map<String, dynamic>>> _contactsStreamController =
      StreamController<List<Map<String, dynamic>>>.broadcast();

  Stream<List<Map<String, dynamic>>> get localContactsStream =>
      _contactsStreamController.stream;

  List<Map<String, dynamic>> get currentContacts =>
      List.unmodifiable(_cachedContacts);

  Future<void> _loadLocalContacts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(raw);
        _cachedContacts.clear();
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            _cachedContacts.add(Map<String, dynamic>.from(item));
          }
        }
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

  //* Create / Add Contact
  Future<void> addContact(
      Map<String, dynamic> contactDetails, String id) async {
    // 1. Save to local storage first for instant offline availability
    final formatted = Map<String, dynamic>.from(contactDetails);
    formatted['id'] = id;
    final existingIndex = _cachedContacts.indexWhere((c) => c['id'] == id);
    if (existingIndex >= 0) {
      _cachedContacts[existingIndex] = formatted;
    } else {
      _cachedContacts.add(formatted);
    }
    await _saveLocalContacts();

    // 2. Sync to Firestore in background
    try {
      await FirebaseFirestore.instance
          .collection('Contacts')
          .doc(id)
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
    return List.from(_cachedContacts);
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
