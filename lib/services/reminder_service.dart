import 'dart:async';

import 'package:carelanka_app/core/firebase/firebase_collections.dart';
import 'package:carelanka_app/core/utils/medication_schedule_helper.dart';
import 'package:carelanka_app/models/daily_dose_item.dart';
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

  Stream<int> watchTakenDosesToday(String userId) {
    return _col.where('userId', isEqualTo: userId).snapshots().map((snap) {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day);
      final end = start.add(const Duration(days: 1));
      var count = 0;
      for (final doc in snap.docs) {
        final d = doc.data();
        final status = (d['status'] as String? ?? '').toLowerCase();
        if (status != 'confirmed' && status != 'taken') continue;
        final scheduled = d['scheduledTime'];
        if (scheduled is! Timestamp) continue;
        final dt = scheduled.toDate();
        if (!dt.isBefore(start) && dt.isBefore(end)) count++;
      }
      return count;
    });
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

  Stream<List<DailyDoseItem>> watchTodayDoses(String userId) {
    final controller = StreamController<List<DailyDoseItem>>();
    QuerySnapshot<Map<String, dynamic>>? lastMeds;
    QuerySnapshot<Map<String, dynamic>>? lastIllnesses;
    QuerySnapshot<Map<String, dynamic>>? lastLogs;

    void emit() {
      if (lastMeds == null || lastIllnesses == null || lastLogs == null) return;
      controller.add(_buildTodayDoses(lastMeds!, lastIllnesses!, lastLogs!));
    }

    final medSub = _firestore
        .collection(FirebaseCollections.medications)
        .where('userId', isEqualTo: userId)
        .snapshots()
        .listen((snap) {
      lastMeds = snap;
      emit();
    });
    final illnessSub = _firestore
        .collection(FirebaseCollections.illnesses)
        .where('userId', isEqualTo: userId)
        .snapshots()
        .listen((snap) {
      lastIllnesses = snap;
      emit();
    });
    final logSub = _col.where('userId', isEqualTo: userId).snapshots().listen((snap) {
      lastLogs = snap;
      emit();
    });

    controller.onCancel = () {
      medSub.cancel();
      illnessSub.cancel();
      logSub.cancel();
    };

    return controller.stream;
  }

  List<DailyDoseItem> _buildTodayDoses(
    QuerySnapshot<Map<String, dynamic>> medSnap,
    QuerySnapshot<Map<String, dynamic>> illnessSnap,
    QuerySnapshot<Map<String, dynamic>> logSnap,
  ) {
    final now = DateTime.now();
    final dayStart = DateTime(now.year, now.month, now.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    final illnessNames = <String, String>{};
    final activeIllnessIds = <String>{};
    for (final doc in illnessSnap.docs) {
      final data = doc.data();
      illnessNames[doc.id] = data['illnessName'] as String? ?? '';
      final status = data['status'] as String? ?? 'active';
      if (status != 'completed') activeIllnessIds.add(doc.id);
    }

    final logsByKey = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    for (final doc in logSnap.docs) {
      final d = doc.data();
      final scheduled = d['scheduledTime'];
      if (scheduled is! Timestamp) continue;
      final dt = scheduled.toDate();
      if (dt.isBefore(dayStart) || !dt.isBefore(dayEnd)) continue;
      final medId = d['medicationId'] as String? ?? '';
      final key = '$medId-${dt.hour}-${dt.minute}';
      logsByKey[key] = doc;
    }

    final doses = <DailyDoseItem>[];
    for (final doc in medSnap.docs) {
      final med = doc.data();
      if (med['active'] != true) continue;
      final illnessId = med['illnessId'] as String? ?? '';
      if (!activeIllnessIds.contains(illnessId)) continue;

      final medId = doc.id;
      final name = med['name'] as String? ?? 'Medication';
      final dosage = med['dosage'] as String? ?? '';
      final condition = illnessNames[illnessId] ?? '';
      final mealTiming = med['mealTiming'] as String? ?? '';
      final times = med['scheduledTimes'] as List? ?? [];

      for (final raw in times) {
        final scheduledAt = MedicationScheduleHelper.parseTimeOnDay(raw.toString(), now);
        if (scheduledAt == null) continue;

        final key = '$medId-${scheduledAt.hour}-${scheduledAt.minute}';
        final log = logsByKey[key];
        String status = 'upcoming';
        String? actionLabel;
        int? latency;
        String? logId;
        DateTime? snoozeUntil;

        if (log != null) {
          final ld = log.data();
          logId = log.id;
          status = (ld['status'] as String? ?? 'confirmed').toLowerCase();
          if (status == 'taken') status = 'confirmed';
          latency = ld['responseLatencyMinutes'] as int?;
          final actual = ld['actualResponseTime'];
          if (actual is Timestamp) {
            actionLabel = DateFormat.jm().format(actual.toDate());
          }
          final snooze = ld['snoozeUntil'];
          if (snooze is Timestamp) snoozeUntil = snooze.toDate();
        } else if (scheduledAt.isBefore(now)) {
          status = 'missed';
          actionLabel = DateFormat.jm().format(scheduledAt);
        }

        doses.add(
          DailyDoseItem(
            medicationId: medId,
            medicationName: name,
            dosage: dosage,
            condition: condition,
            scheduledLabel: raw.toString(),
            scheduledAt: scheduledAt,
            status: status,
            actionLabel: actionLabel,
            mealTiming: mealTiming,
            latencyMinutes: latency,
            logId: logId,
            snoozeUntil: snoozeUntil,
          ),
        );
      }
    }

    doses.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return doses;
  }

  Future<void> logDose({
    required String userId,
    required String medicationId,
    required String medicationName,
    required String condition,
    required DateTime scheduledTime,
    required String status,
    int responseLatencyMinutes = 0,
    DateTime? snoozeUntil,
    String? existingLogId,
  }) async {
    final payload = {
      'userId': userId,
      'medicationId': medicationId,
      'medicationName': medicationName,
      'condition': condition,
      'scheduledTime': Timestamp.fromDate(scheduledTime),
      'actualResponseTime': Timestamp.fromDate(DateTime.now()),
      'status': status,
      'responseLatencyMinutes': responseLatencyMinutes,
      'createdAt': Timestamp.fromDate(DateTime.now()),
      if (snoozeUntil != null) 'snoozeUntil': Timestamp.fromDate(snoozeUntil),
    };

    if (existingLogId != null && existingLogId.isNotEmpty) {
      await _col.doc(existingLogId).set(payload, SetOptions(merge: true));
    } else {
      await _col.add(payload);
    }
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
