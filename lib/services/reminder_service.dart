import 'package:carelanka_app/core/firebase/firebase_collections.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ReminderService {
  ReminderService({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection(FirebaseCollections.reminderLogs);

  Stream<List<Map<String, String>>> watchReminderMaps(String userId) {
    return _col.where('userId', isEqualTo: userId).snapshots().map(
          (snap) => snap.docs.map(_toUiMap).toList(),
        );
  }

  Map<String, String> _toUiMap(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final status = (d['status'] as String? ?? 'confirmed').toLowerCase();
    final scheduled = d['scheduledTime'];
    String scheduledStr = '—';
    String dateGroup = 'Earlier';
    if (scheduled is Timestamp) {
      final dt = scheduled.toDate();
      scheduledStr = DateFormat.jm().format(dt);
      final now = DateTime.now();
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
        dateGroup = 'Today, ${DateFormat('MMM d').format(dt)}';
      } else if (dt.year == now.year && dt.month == now.month && dt.day == now.day - 1) {
        dateGroup = 'Yesterday, ${DateFormat('MMM d').format(dt)}';
      } else {
        dateGroup = DateFormat('EEEE, MMM d').format(dt);
      }
    }

    final actual = d['actualResponseTime'];
    String actionTime = '—';
    if (actual is Timestamp) {
      actionTime = DateFormat.jm().format(actual.toDate());
    }

    final latency = d['responseLatencyMinutes'] as int? ?? 0;
    String timing = 'on_time';
    String? lateBy;
    if (status == 'confirmed' && latency > 0) {
      timing = 'late';
      lateBy = '+$latency min';
    }

    return {
      'medication': d['medicationName'] as String? ?? d['name'] as String? ?? 'Medication',
      'condition': d['condition'] as String? ?? '',
      'scheduled': scheduledStr,
      'actionTime': actionTime,
      'status': status == 'taken' ? 'confirmed' : status,
      'timing': timing,
      if (lateBy != null) 'lateBy': lateBy,
      'dateGroup': dateGroup,
    };
  }

  /// Adherence: confirmed / total logs in range.
  Future<double> calculateAdherencePercent(String userId, {DateTime? start, DateTime? end}) async {
    Query<Map<String, dynamic>> query = _col.where('userId', isEqualTo: userId);
    final snap = await query.get();
    if (snap.docs.isEmpty) return 0;

    var total = 0;
    var taken = 0;
    for (final doc in snap.docs) {
      final d = doc.data();
      final created = d['createdAt'];
      if (created is! Timestamp) continue;
      final dt = created.toDate();
      if (start != null && dt.isBefore(start)) continue;
      if (end != null && dt.isAfter(end)) continue;
      total++;
      final status = (d['status'] as String? ?? '').toLowerCase();
      if (status == 'confirmed' || status == 'taken') taken++;
    }
    if (total == 0) return 0;
    return (taken / total) * 100;
  }
}
