import 'package:carelanka_app/core/firebase/firebase_collections.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AllergyService {
  AllergyService({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection(FirebaseCollections.allergies);

  Stream<List<Map<String, String>>> watchAllergyMaps(String userId) {
    return _col.where('userId', isEqualTo: userId).snapshots().map(
          (snap) => snap.docs.map(_toUiMap).toList(),
        );
  }

  Map<String, String> _toUiMap(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return {
      'allergyId': doc.id,
      'name': d['allergyName'] as String? ?? '',
      'severity': d['severity'] as String? ?? '',
      'category': _categoryFromNotes(d['notes'] as String?),
      'notes': d['notes'] as String? ?? '',
    };
  }

  String _categoryFromNotes(String? notes) {
    if (notes == null || !notes.contains('|')) return 'General';
    return notes.split('|').first;
  }

  Future<void> addAllergy({
    required String userId,
    required String allergyName,
    required String severity,
    required String category,
    String notes = '',
  }) async {
    final ref = _col.doc();
    await ref.set({
      'allergyId': ref.id,
      'userId': userId,
      'allergyName': allergyName,
      'severity': severity,
      'notes': '$category${notes.isNotEmpty ? '|$notes' : ''}',
      'createdAt': Timestamp.fromDate(DateTime.now()),
    });
  }
}
