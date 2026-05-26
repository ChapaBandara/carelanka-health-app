import 'package:carelanka_app/core/firebase/firebase_collections.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class IllnessService {
  IllnessService({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection(FirebaseCollections.illnesses);

  Stream<List<Map<String, String>>> watchIllnessMaps(String userId) {
    return _col.where('userId', isEqualTo: userId).snapshots().map((snap) {
      final list = snap.docs.map(_toUiMap).toList();
      return list;
    });
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
      'meds': '0 medications',
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
    String since = '';
    if (diagnosed is Timestamp) {
      since = 'Since ${DateFormat('d MMM yyyy').format(diagnosed.toDate())}';
    }

    return {
      'illnessId': docId,
      'name': name,
      'since': since,
      'initials': initials,
      'notes': d['notes'] as String? ?? '',
      'status': d['status'] as String? ?? 'active',
    };
  }
}
