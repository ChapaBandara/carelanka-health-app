import 'package:carelanka_app/core/firebase/firebase_collections.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AlertService {
  AlertService({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection(FirebaseCollections.alerts);

  Stream<List<Map<String, String>>> watchAlertMaps(String userId) {
    return _col.where('userId', isEqualTo: userId).snapshots().map(
          (snap) => snap.docs.map(_toUiMap).toList(),
        );
  }

  Map<String, String> _toUiMap(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final type = (d['type'] as String? ?? 'general').toLowerCase();
    final created = d['createdAt'];
    String time = '';
    if (created is Timestamp) {
      time = DateFormat('MMM d \'at\' h:mm a').format(created.toDate());
    }

    String category;
    String accent;
    String tint;
    switch (type) {
      case 'drug':
        category = 'DRUG CONFLICT';
        accent = 'red';
        tint = 'red';
        break;
      case 'allergy':
        category = 'ALLERGY WARNING';
        accent = 'red';
        tint = 'red';
        break;
      case 'missed':
        category = 'MISSED DOSE';
        accent = 'orange';
        tint = 'orange';
        break;
      case 'checkup':
        category = 'CHECKUP';
        accent = 'teal';
        tint = 'white';
        break;
      default:
        category = 'GENERAL';
        accent = 'purple';
        tint = 'white';
    }

    return {
      'alertId': doc.id,
      'type': type,
      'category': category,
      'title': d['message'] as String? ?? '',
      'time': time,
      'accent': accent,
      'tint': tint,
      'read': '${d['read'] == true}',
    };
  }

  Future<void> markAsRead(String alertId) async {
    await _col.doc(alertId).update({'read': true});
  }

  Future<bool> hasUnreadCheckupAlert(String userId) async {
    final snap = await _col.where('userId', isEqualTo: userId).get();
    return snap.docs.any((d) {
      final data = d.data();
      return data['type'] == 'checkup' && data['read'] != true;
    });
  }

  Future<void> createCheckupAlert({
    required String userId,
    required int daysSinceCheckup,
  }) async {
    final ref = _col.doc();
    await ref.set({
      'userId': userId,
      'type': 'checkup',
      'message': "You haven't had a checkup in $daysSinceCheckup days. Schedule a visit with your doctor.",
      'read': false,
      'createdAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> dismissUnreadCheckupAlerts(String userId) async {
    final snap = await _col.where('userId', isEqualTo: userId).get();
    final unread = snap.docs.where((d) {
      final data = d.data();
      return data['type'] == 'checkup' && data['read'] != true;
    });
    if (unread.isEmpty) return;
    final batch = _firestore.batch();
    for (final doc in unread) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }
}
