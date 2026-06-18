import 'dart:convert';
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
    return _col.where('userId', isEqualTo: userId).snapshots().map((snap) {
      final list = snap.docs.map(_toUiMap).toList();
      list.sort((a, b) {
        final aMs = int.tryParse(a['visitDateMillis'] ?? '0') ?? 0;
        final bMs = int.tryParse(b['visitDateMillis'] ?? '0') ?? 0;
        return bMs.compareTo(aMs);
      });
      return list;
    });
  }

  Map<String, String> _toUiMap(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final visit = d['visitDate'];
    String dateStr = '';
    String shortDate = '';
    String monthDay = '';
    int? visitMillis;
    if (visit is Timestamp) {
      final dt = visit.toDate();
      visitMillis = dt.millisecondsSinceEpoch;
      dateStr = DateFormat('d MMM yyyy').format(dt);
      shortDate = DateFormat('MMM d').format(dt);
      monthDay = DateFormat('MMM d, yyyy').format(dt);
    }
    final doctor = d['doctorName'] as String? ?? '';
    final diagnosis = d['diagnosis'] as String? ?? '';
    final docType = d['documentType'] as String? ?? 'Record';
    final title = diagnosis.isNotEmpty ? '$diagnosis — $doctor' : 'Dr. $doctor — $shortDate';
    return {
      'recordId': doc.id,
      'date': dateStr,
      'shortDate': shortDate,
      'monthDay': monthDay,
      'doctor': doctor,
      'place': d['hospital'] as String? ?? '',
      'diagnosis': diagnosis,
      'notes': d['notes'] as String? ?? '',
      'tag': docType,
      'documentType': docType,
      'documentUrl': d['documentUrl'] as String? ?? '',
      'title': title,
      'linkedIllness': d['linkedIllness'] as String? ?? '',
      if (visitMillis != null) 'visitDateMillis': '$visitMillis',
    };
  }

  List<Map<String, String>> filterRecords(
    List<Map<String, String>> records, {
    DateTime? from,
    DateTime? to,
    String doctorQuery = '',
    String diagnosisQuery = '',
    bool attachOnly = false,
  }) {
    return records.where((r) {
      if (from != null || to != null) {
        final millis = int.tryParse(r['visitDateMillis'] ?? '') ?? 0;
        if (millis == 0) return false;
        final visit = DateTime.fromMillisecondsSinceEpoch(millis);
        final day = DateTime(visit.year, visit.month, visit.day);
        if (from != null) {
          final fromDay = DateTime(from.year, from.month, from.day);
          if (day.isBefore(fromDay)) return false;
        }
        if (to != null) {
          final toDay = DateTime(to.year, to.month, to.day);
          if (day.isAfter(toDay)) return false;
        }
      }

      final doctor = (r['doctor'] ?? '').toLowerCase();
      final dq = doctorQuery.trim().toLowerCase();
      if (dq.isNotEmpty && !doctor.contains(dq)) return false;

      final diagnosis = (r['diagnosis'] ?? '').toLowerCase();
      final diagQ = diagnosisQuery.trim().toLowerCase();
      if (diagQ.isNotEmpty && diagQ != 'all' && !diagnosis.contains(diagQ)) return false;

      if (attachOnly) {
        final url = r['documentUrl'] ?? '';
        if (url.isEmpty) return false;
      }

      return true;
    }).toList();
  }

  List<Map<String, String>> searchRecords(List<Map<String, String>> records, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return records;
    return records.where((r) {
      final haystack = [
        r['title'],
        r['doctor'],
        r['diagnosis'],
        r['place'],
        r['tag'],
        r['documentType'],
      ].join(' ').toLowerCase();
      return haystack.contains(q);
    }).toList();
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
      documentUrl = await _uploadDocument(userId, documentFile);
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

  Future<void> updateRecord({
    required String recordId,
    required String userId,
    required DateTime visitDate,
    required String doctorName,
    required String hospital,
    required String diagnosis,
    required String notes,
    required String documentType,
    File? documentFile,
    String? existingDocumentUrl,
  }) async {
    var documentUrl = existingDocumentUrl ?? '';
    if (documentFile != null) {
      documentUrl = await _uploadDocument(userId, documentFile) ?? documentUrl;
    }

    await _col.doc(recordId).update({
      'visitDate': Timestamp.fromDate(visitDate),
      'doctorName': doctorName,
      'hospital': hospital,
      'diagnosis': diagnosis,
      'notes': notes,
      'documentUrl': documentUrl,
      'documentType': documentType,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> deleteRecord(String recordId) async {
    await _col.doc(recordId).delete();
  }

  Future<String?> _uploadDocument(String userId, File documentFile) async {
    final ext = documentFile.path.split('.').last.toLowerCase();
    final safeExt = ['jpg', 'jpeg', 'png', 'pdf', 'webp'].contains(ext) ? ext : 'jpg';
    final path = 'users/$userId/records/${DateTime.now().millisecondsSinceEpoch}.$safeExt';

    try {
      final ref = _storage.ref().child(path);
      await ref.putFile(
        documentFile,
        SettableMetadata(contentType: safeExt == 'pdf' ? 'application/pdf' : 'image/jpeg'),
      );
      return await ref.getDownloadURL();
    } catch (_) {
      try {
        final bytes = await documentFile.readAsBytes();
        final encoded = base64Encode(bytes);
        return 'data:image/jpeg;base64,$encoded';
      } catch (_) {
        return null;
      }
    }
  }
}
