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
    final condition = d['condition'] as String? ?? d['linkedIllness'] as String? ?? '';
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
      'condition': condition,
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
    final safeFrom = (from != null && to != null && from.isAfter(to)) ? to : from;
    final safeTo = (from != null && to != null && from.isAfter(to)) ? from : to;

    return records.where((r) {
      if (safeFrom != null || safeTo != null) {
        final millis = int.tryParse(r['visitDateMillis'] ?? '') ?? 0;
        if (millis == 0) return false;
        final visit = DateTime.fromMillisecondsSinceEpoch(millis);
        final day = DateTime(visit.year, visit.month, visit.day);
        if (safeFrom != null) {
          final fromDay = DateTime(safeFrom.year, safeFrom.month, safeFrom.day);
          if (day.isBefore(fromDay)) return false;
        }
        if (safeTo != null) {
          final toDay = DateTime(safeTo.year, safeTo.month, safeTo.day);
          if (day.isAfter(toDay)) return false;
        }
      }

      final doctor = (r['doctor'] ?? '').toLowerCase();
      final dq = doctorQuery.trim().toLowerCase();
      if (dq.isNotEmpty && !doctor.contains(dq)) return false;

      final diagnosis = (r['diagnosis'] ?? '').toLowerCase();
      final condition = (r['condition'] ?? '').toLowerCase();
      final diagQ = diagnosisQuery.trim().toLowerCase();
      if (diagQ.isNotEmpty && diagQ != 'all') {
        if (!diagnosis.contains(diagQ) && !condition.contains(diagQ)) return false;
      }

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
    // Try Firebase Storage first
    try {
      final ext = documentFile.path.split('.').last.toLowerCase();
      final safeExt = ['jpg', 'jpeg', 'png', 'pdf', 'webp'].contains(ext)
          ? ext
          : 'jpg';
      final path =
          'users/$userId/records/${DateTime.now().millisecondsSinceEpoch}.$safeExt';
      final ref = _storage.ref().child(path);
      final contentType = switch (safeExt) {
        'pdf' => 'application/pdf',
        'png' => 'image/png',
        'webp' => 'image/webp',
        _ => 'image/jpeg',
      };
      await ref.putFile(
        documentFile,
        SettableMetadata(contentType: contentType),
      ).timeout(const Duration(seconds: 30));
      return await ref.getDownloadURL();
    } catch (storageError) {
      // Firebase Storage not available — store as base64 in Firestore
      // This works without the Blaze plan
      try {
        final bytes = await documentFile.readAsBytes();
        // Limit to 500KB to stay within Firestore 1MB document limit
        if (bytes.length > 500000) {
          throw Exception(
              'File too large. Please select an image under 500KB.');
        }
        final ext = documentFile.path.split('.').last.toLowerCase();
        final base64Str = base64Encode(bytes);
        // Return as data URL so document viewer can display it
        final mimeType = ext == 'png' ? 'image/png' : 'image/jpeg';
        return 'data:$mimeType;base64,$base64Str';
      } catch (e) {
        if (e.toString().contains('too large')) rethrow;
        throw Exception(
            'Could not save document. Please try a smaller image.');
      }
    }
  }
}
