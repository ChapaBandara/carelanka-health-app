import 'package:carelanka_app/core/firebase/firebase_collections.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MedicationService {
  MedicationService({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection(FirebaseCollections.medications);

  Stream<List<Map<String, dynamic>>> watchMedications(String userId) {
    return _col.where('userId', isEqualTo: userId).snapshots().map(
          (snap) => snap.docs.map((d) => {...d.data(), 'medicationId': d.id}).toList(),
        );
  }

  Stream<List<Map<String, dynamic>>> watchMedicationsForIllness({
    required String userId,
    required String illnessId,
  }) {
    return _col
        .where('userId', isEqualTo: userId)
        .where('illnessId', isEqualTo: illnessId)
        .snapshots()
        .map((snap) => snap.docs.map((d) => {...d.data(), 'medicationId': d.id}).toList());
  }

  Future<String> addMedication({
    required String userId,
    required String illnessId,
    required String name,
    required String dosage,
    required String frequency,
    required List<String> scheduledTimes,
    String category = 'General',
    String mealTiming = 'anytime',
    int prescribedDays = 30,
    int stockCount = 30,
    int lowStockThreshold = 5,
    bool hasConflictWarning = false,
  }) async {
    final ref = _col.doc();
    await ref.set({
      'medicationId': ref.id,
      'userId': userId,
      'illnessId': illnessId,
      'name': name,
      'dosage': dosage,
      'category': category,
      'frequency': frequency,
      'scheduledTimes': scheduledTimes,
      'mealTiming': mealTiming,
      'prescribedDays': prescribedDays,
      'stockCount': stockCount,
      'lowStockThreshold': lowStockThreshold,
      'startDate': Timestamp.fromDate(DateTime.now()),
      'endDate': null,
      'active': true,
      'hasConflictWarning': hasConflictWarning,
      'originalScheduledTimes': scheduledTimes,
      'createdAt': Timestamp.fromDate(DateTime.now()),
    });
    return ref.id;
  }

  Future<void> deleteMedication(String medicationId) async {
    await _col.doc(medicationId).delete();
  }

  Future<void> updateMedication({
    required String medicationId,
    required String name,
    required String dosage,
    required String frequency,
    required List<String> scheduledTimes,
    String category = 'General',
    String mealTiming = 'anytime',
    int prescribedDays = 30,
    int stockCount = 30,
    int lowStockThreshold = 5,
    bool hasConflictWarning = false,
  }) async {
    await _col.doc(medicationId).update({
      'name': name,
      'dosage': dosage,
      'category': category,
      'frequency': frequency,
      'scheduledTimes': scheduledTimes,
      'mealTiming': mealTiming,
      'prescribedDays': prescribedDays,
      'stockCount': stockCount,
      'lowStockThreshold': lowStockThreshold,
      'hasConflictWarning': hasConflictWarning,
      'originalScheduledTimes': scheduledTimes,
    });
  }

  List<Map<String, dynamic>> filterActiveForIllnesses(
    List<Map<String, dynamic>> medications,
    Set<String> activeIllnessIds,
  ) {
    return medications.where((m) {
      if (m['active'] != true) return false;
      final illnessId = m['illnessId'] as String? ?? '';
      return activeIllnessIds.contains(illnessId);
    }).toList();
  }

  Future<String?> findIllnessIdByName(String userId, String illnessName) async {
    final snap = await _firestore
        .collection(FirebaseCollections.illnesses)
        .where('userId', isEqualTo: userId)
        .where('illnessName', isEqualTo: illnessName.trim())
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return snap.docs.first.id;
  }
}
