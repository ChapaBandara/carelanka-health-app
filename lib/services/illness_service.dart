import 'dart:async';

import 'package:carelanka_app/core/firebase/firebase_collections.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class IllnessService {
  IllnessService({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection(FirebaseCollections.illnesses);

  CollectionReference<Map<String, dynamic>> get _medCol =>
      _firestore.collection(FirebaseCollections.medications);

  Stream<List<Map<String, String>>> watchIllnessMaps(String userId) {
    final controller = StreamController<List<Map<String, String>>>.broadcast();
    QuerySnapshot<Map<String, dynamic>>? lastIllnesses;
    QuerySnapshot<Map<String, dynamic>>? lastMeds;

    void emit() {
      if (lastIllnesses == null) return;
      final counts = _medCountsByIllness(lastMeds?.docs ?? []);
      final list = lastIllnesses!.docs.map((doc) {
        final map = _toUiMap(doc);
        map['meds'] = _medCountLabel(counts[doc.id] ?? 0);
        return map;
      }).toList();
      controller.add(list);
    }

    final illnessSub = _col.where('userId', isEqualTo: userId).snapshots().listen((snap) {
      lastIllnesses = snap;
      emit();
    });
    final medSub = _medCol.where('userId', isEqualTo: userId).snapshots().listen((snap) {
      lastMeds = snap;
      emit();
    });

    controller.onCancel = () {
      illnessSub.cancel();
      medSub.cancel();
    };

    return controller.stream;
  }

  Map<String, int> _medCountsByIllness(List<QueryDocumentSnapshot<Map<String, dynamic>>> medDocs) {
    final counts = <String, int>{};
    for (final doc in medDocs) {
      final illnessId = doc.data()['illnessId'] as String? ?? '';
      if (illnessId.isEmpty) continue;
      counts[illnessId] = (counts[illnessId] ?? 0) + 1;
    }
    return counts;
  }

  String _medCountLabel(int count) {
    if (count == 1) return '1 medication';
    return '$count medications';
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchIllness(String illnessId) {
    return _col.doc(illnessId).snapshots();
  }

  Future<String> addIllness({
    required String userId,
    required String illnessName,
    required DateTime diagnosedDate,
    String? doctorName,
    String durationType = 'ongoing',
    String? notes,
  }) async {
    final ref = _col.doc();
    await ref.set({
      'illnessId': ref.id,
      'userId': userId,
      'illnessName': illnessName,
      'diagnosedDate': Timestamp.fromDate(diagnosedDate),
      'doctorName': doctorName ?? '',
      'durationType': durationType,
      'estimatedEndDate': null,
      'status': 'active',
      'notes': notes ?? '',
      'createdAt': Timestamp.fromDate(DateTime.now()),
    });
    return ref.id;
  }

  Future<void> completeIllness(String illnessId) async {
    await _col.doc(illnessId).update({
      'status': 'completed',
      'completedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> deleteIllness({
    required String userId,
    required String illnessId,
  }) async {
    final batch = _firestore.batch();
    batch.delete(_col.doc(illnessId));

    final meds = await _medCol
        .where('userId', isEqualTo: userId)
        .where('illnessId', isEqualTo: illnessId)
        .get();
    for (final doc in meds.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  Map<String, String> _toUiMap(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final name = d['illnessName'] as String? ?? '';
    final parts = name.trim().split(RegExp(r'\s+'));
    final initials = parts.isEmpty
        ? '?'
        : parts.length == 1
            ? parts.first[0].toUpperCase()
            : '${parts.first[0]}${parts.last[0]}'.toUpperCase();

    final diagnosed = d['diagnosedDate'];
    String since = 'Recently added';
    if (diagnosed is Timestamp) {
      since = 'Since ${DateFormat('d MMM yyyy').format(diagnosed.toDate())}';
    }

    final status = d['status'] as String? ?? 'active';
    return {
      'illnessId': doc.id,
      'name': name,
      'since': since,
      'chip2': status == 'completed' ? 'Completed' : 'Ongoing',
      'initials': initials,
      'status': status,
      'notes': d['notes'] as String? ?? '',
    };
  }

  Map<String, String> illnessDocToUiMap(Map<String, dynamic> d, String docId) {
    final name = d['illnessName'] as String? ?? '';
    final parts = name.trim().split(RegExp(r'\s+'));
    final initials = parts.isEmpty
        ? '?'
        : parts.length == 1
            ? parts.first[0].toUpperCase()
            : '${parts.first[0]}${parts.last[0]}'.toUpperCase();

    final diagnosed = d['diagnosedDate'];
    DateTime? diagnosedDate;
    String diagnosedLabel = '';
    String since = '';
    if (diagnosed is Timestamp) {
      diagnosedDate = diagnosed.toDate();
      diagnosedLabel = 'Diagnosed: ${DateFormat('MMM d, yyyy').format(diagnosedDate)}';
      since = 'Since ${DateFormat('d MMM yyyy').format(diagnosedDate)}';
    }

    final durationType = d['durationType'] as String? ?? 'long_term';
    final isLongTerm = durationType == 'long_term' || durationType == 'ongoing';
    final durationBadge = isLongTerm ? 'Long-term' : 'Short-term';

    final estimatedEnd = d['estimatedEndDate'];
    String endsLabel = '';
    if (!isLongTerm && estimatedEnd is Timestamp) {
      final end = estimatedEnd.toDate();
      final daysLeft = end.difference(DateTime.now()).inDays;
      final leftText = daysLeft > 0 ? ' ($daysLeft days left)' : '';
      endsLabel = 'Ends: ${DateFormat('MMM d, yyyy').format(end)}$leftText';
    }

    return {
      'illnessId': docId,
      'name': name,
      'since': since,
      'diagnosedLabel': diagnosedLabel,
      'endsLabel': endsLabel,
      'durationBadge': durationBadge,
      'initials': initials,
      'notes': d['notes'] as String? ?? '',
      'status': d['status'] as String? ?? 'active',
      'doctorName': d['doctorName'] as String? ?? '',
    };
  }
}
