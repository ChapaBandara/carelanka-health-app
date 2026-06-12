import 'dart:io';

import 'package:carelanka_app/core/firebase/firebase_collections.dart';
import 'package:carelanka_app/models/user_profile.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class UserService {
  UserService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  static Map<String, dynamic> defaultNotificationPreferences() => {
        'medicationReminders': true,
        'missedDoseAlerts': true,
        'appointments': true,
        'checkupSuggestions': true,
        'drugConflictWarnings': true,
        'weeklySummary': true,
        'lowStockReminders': true,
        'quietHours': true,
        'snoozeDuration': '15 minutes',
        'alerts': true,
        'push': true,
        'sms': true,
        'email': true,
      };

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection(FirebaseCollections.users);

  Future<void> createUserDocument({
    required String uid,
    required String fullName,
    required String email,
    required String phone,
    DateTime? dateOfBirth,
    String? gender,
    String? bloodType,
    String? emergencyContactName,
    String? emergencyContactPhone,
  }) async {
    await _users.doc(uid).set({
      'uid': uid,
      'fullName': fullName,
      'email': email,
      'phone': phone.replaceAll(RegExp(r'\D'), ''),
      if (dateOfBirth != null) 'dateOfBirth': Timestamp.fromDate(dateOfBirth),
      if (gender != null) 'gender': gender,
      if (bloodType != null) 'bloodType': bloodType,
      if (emergencyContactName != null) 'emergencyContactName': emergencyContactName,
      if (emergencyContactPhone != null) 'emergencyContactPhone': emergencyContactPhone,
      'createdAt': Timestamp.fromDate(DateTime.now()),
      'adherenceScore': 0.0,
      'averageVisitGapDays': 30,
      'notificationPreferences': defaultNotificationPreferences(),
    });
  }

  Future<UserProfile?> getUserProfile(String uid) async {
    final doc = await _users.doc(uid).get();
    if (!doc.exists) return null;
    return _profileFromDoc(doc);
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchUser(String uid) {
    return _users.doc(uid).snapshots();
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    await _users.doc(uid).update(data);
  }

  Future<String> uploadProfileImage(String uid, File file) async {
    final ref = _storage.ref().child('users/$uid/profile.jpg');
    await ref.putFile(file);
    return ref.getDownloadURL();
  }

  Future<Map<String, dynamic>?> getNotificationPreferences(String uid) async {
    final doc = await _users.doc(uid).get();
    if (!doc.exists) return null;
    return Map<String, dynamic>.from(
      doc.data()?['notificationPreferences'] as Map? ?? defaultNotificationPreferences(),
    );
  }

  Future<void> updateNotificationPreferences(String uid, Map<String, dynamic> prefs) async {
    await _users.doc(uid).update({'notificationPreferences': prefs});
  }

  Future<void> deleteUserData(String uid) async {
    await _deleteWhereField(FirebaseCollections.illnesses, 'userId', uid);
    await _deleteWhereField(FirebaseCollections.medications, 'userId', uid);
    await _deleteWhereField(FirebaseCollections.reminderLogs, 'userId', uid);
    await _deleteWhereField(FirebaseCollections.healthRecords, 'userId', uid);
    await _deleteWhereField(FirebaseCollections.appointments, 'userId', uid);
    await _deleteWhereField(FirebaseCollections.allergies, 'userId', uid);
    await _deleteWhereField(FirebaseCollections.alerts, 'userId', uid);
    await _deleteWhereField(FirebaseCollections.familyProfiles, 'ownerId', uid);
    await _users.doc(uid).delete();
  }

  Future<void> _deleteWhereField(String collection, String field, String value) async {
    final snap = await _firestore.collection(collection).where(field, isEqualTo: value).get();
    if (snap.docs.isEmpty) return;
    final batch = _firestore.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  UserProfile _profileFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    final ts = d['dateOfBirth'];
    DateTime? dob;
    if (ts is Timestamp) dob = ts.toDate();

    return UserProfile(
      fullName: d['fullName'] as String? ?? '',
      email: d['email'] as String? ?? '',
      phone: d['phone'] as String? ?? '',
      dateOfBirth: dob,
      gender: d['gender'] as String?,
      bloodType: d['bloodType'] as String?,
      profileImageUrl: d['profileImageUrl'] as String?,
      emergencyContactName: d['emergencyContactName'] as String?,
      emergencyContactPhone: d['emergencyContactPhone'] as String?,
      isDependent: d['isDependent'] as bool? ?? false,
      guardianName: d['guardianName'] as String?,
    );
  }
}
