import 'dart:io';

import 'package:carelanka_app/core/firebase/firebase_collections.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';

class HealthRecordService {
  HealthRecordService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection(FirebaseCollections.healthRecords);

  Stream<List<Map<String, String>>> watchRecordMaps(String userId) {
    return _col.where('userId', isEqualTo: userId).snapshots().map(
          (snap) => snap.docs.map(_toUiMap).toList(),
        );
  }

  Map<String, String> _toUiMap(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final visit = d['visitDate'];
    String dateStr = '';
    if (visit is Timestamp) {
      dateStr = DateFormat('d MMM yyyy').format(visit.toDate());
    }
    return {
      'recordId': doc.id,
      'date': dateStr,
      'doctor': d['doctorName'] as String? ?? '',
      'place': d['hospital'] as String? ?? '',
      'tag': d['documentType'] as String? ?? d['diagnosis'] as String? ?? 'Record',
      'documentUrl': d['documentUrl'] as String? ?? '',
    };
  }

  Future<void> addRecord({
    required String userId,
    required DateTime visitDate,
    required String doctorName,
    required String hospital,
    required String diagnosis,
    required String notes,
    required String documentType,
    File? documentFile,
  }) async {
    String? documentUrl;
    if (documentFile != null) {
      final ref = _storage.ref().child('users/$userId/records/${DateTime.now().millisecondsSinceEpoch}');
      await ref.putFile(documentFile);
      documentUrl = await ref.getDownloadURL();
    }

    final docRef = _col.doc();
    await docRef.set({
      'recordId': docRef.id,
      'userId': userId,
      'visitDate': Timestamp.fromDate(visitDate),
      'doctorName': doctorName,
      'hospital': hospital,
      'diagnosis': diagnosis,
      'notes': notes,
      'documentUrl': documentUrl ?? '',
      'documentType': documentType,
      'createdAt': Timestamp.fromDate(DateTime.now()),
    });
  }
}
