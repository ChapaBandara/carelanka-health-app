import 'dart:async';

import 'package:carelanka_app/core/firebase/firebase_collections.dart';
import 'package:carelanka_app/core/utils/medication_schedule_helper.dart';
import 'package:carelanka_app/models/daily_dose_item.dart';
import 'package:carelanka_app/services/adherence_service.dart';
import 'package:carelanka_app/services/notification_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
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

  Stream<List<Map<String, dynamic>>> watchAllDoseHistory(String userId) {
    final controller = StreamController<List<Map<String, dynamic>>>();
    QuerySnapshot<Map<String, dynamic>>? lastMeds;
    QuerySnapshot<Map<String, dynamic>>? lastIllnesses;
    QuerySnapshot<Map<String, dynamic>>? lastLogs;

    void emit() {
      if (lastMeds == null || lastIllnesses == null || lastLogs == null) return;
      controller.add(_buildFullDoseHistory(lastMeds!, lastIllnesses!, lastLogs!));
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
    final logSub = _col
        .where('userId', isEqualTo: userId)
        .orderBy('scheduledTime', descending: true)
        .snapshots()
        .listen((snap) {
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

  Stream<List<Map<String, dynamic>>> watchTodayReminderLogs(String userId) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    return _col
        .where('userId', isEqualTo: userId)
        .where('scheduledTime', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('scheduledTime', isLessThan: Timestamp.fromDate(end))
        .orderBy('scheduledTime', descending: true)
        .snapshots()
        .map((snap) {
      return snap.docs.map((d) {
        final data = d.data();
        final scheduled = data['scheduledTime'];
        final actual = data['actualResponseTime'];
        return {
          ...data,
          'logId': d.id,
          'scheduledTime': scheduled is Timestamp ? scheduled.toDate() : null,
          'actualResponseTime': actual is Timestamp ? actual.toDate() : null,
          'snoozeUntil': data['snoozeUntil'] is Timestamp
              ? (data['snoozeUntil'] as Timestamp).toDate()
              : null,
        };
      }).toList();
    });
  }

  Stream<List<Map<String, dynamic>>> watchTodayLogsDeduped(String userId) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));

    return _col
        .where('userId', isEqualTo: userId)
        .where('scheduledTime', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('scheduledTime', isLessThan: Timestamp.fromDate(end))
        .orderBy('scheduledTime', descending: false)
        .snapshots()
        .map((snap) {
      final seen = <String>{};
      final result = <Map<String, dynamic>>[];

      for (final doc in snap.docs) {
        final data = doc.data();
        final medId = data['medicationId'] as String? ?? '';
        final scheduled = data['scheduledTime'];
        DateTime? scheduledDt;
        if (scheduled is Timestamp) scheduledDt = scheduled.toDate();

        // Dedup key: medicationId + hour + minute of scheduledTime
        final dedupKey = '${medId}_${scheduledDt?.hour.toString() ?? ''}_${scheduledDt?.minute.toString() ?? ''}';

        if (seen.contains(dedupKey)) continue;
        seen.add(dedupKey);

        result.add({
          ...data,
          'logId': doc.id,
          'scheduledTime': scheduledDt,
          'actualResponseTime': data['actualResponseTime'] is Timestamp
              ? (data['actualResponseTime'] as Timestamp).toDate()
              : null,
          'snoozeUntil': data['snoozeUntil'] is Timestamp
              ? (data['snoozeUntil'] as Timestamp).toDate()
              : null,
        });
      }

      // Sort descending after dedup
      result.sort((a, b) {
        final aT = a['scheduledTime'] as DateTime?;
        final bT = b['scheduledTime'] as DateTime?;
        if (aT == null || bT == null) return 0;
        return bT.compareTo(aT);
      });

      return result;
    });
  }

  List<Map<String, dynamic>> _buildFullDoseHistory(
    QuerySnapshot<Map<String, dynamic>> medSnap,
    QuerySnapshot<Map<String, dynamic>> illnessSnap,
    QuerySnapshot<Map<String, dynamic>> logSnap,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final endDayExclusive = today.add(const Duration(days: 1));

    final illnessNames = <String, String>{};
    final activeIllnessIds = <String>{};
    for (final doc in illnessSnap.docs) {
      final data = doc.data();
      illnessNames[doc.id] = data['illnessName'] as String? ?? '';
      final status = data['status'] as String? ?? 'active';
      if (status != 'completed') activeIllnessIds.add(doc.id);
    }

    String doseKey(String medId, DateTime scheduledAt) =>
        '$medId-${scheduledAt.year}-${scheduledAt.month}-${scheduledAt.day}-${scheduledAt.hour}-${scheduledAt.minute}';

    final loggedKeys = <String>{};
    final results = <Map<String, dynamic>>[];

    for (final doc in logSnap.docs) {
      final d = doc.data();
      final scheduled = d['scheduledTime'];
      if (scheduled is! Timestamp) continue;
      final scheduledAt = scheduled.toDate();

      final medId = d['medicationId'] as String? ?? '';
      loggedKeys.add(doseKey(medId, scheduledAt));

      var status = (d['status'] as String? ?? 'confirmed').toLowerCase();
      if (status == 'taken') status = 'confirmed';

      DateTime? actualResponseTime;
      final actual = d['actualResponseTime'];
      if (actual is Timestamp) {
        actualResponseTime = actual.toDate();
      }

      DateTime? snoozeUntil;
      final snooze = d['snoozeUntil'];
      if (snooze is Timestamp) {
        snoozeUntil = snooze.toDate();
      }

      results.add({
        ...d,
        'logId': doc.id,
        'medicationId': medId,
        'medicationName': d['medicationName'] as String? ?? d['name'] as String? ?? 'Medication',
        'condition': d['condition'] as String? ?? '',
        'scheduledTime': scheduledAt,
        'actualResponseTime': actualResponseTime,
        'snoozeUntil': snoozeUntil,
        'status': status,
      });
    }

    for (final doc in medSnap.docs) {
      final med = doc.data();
      if (med['active'] != true) continue;
      final illnessId = med['illnessId'] as String? ?? '';
      if (!activeIllnessIds.contains(illnessId)) continue;

      final medId = doc.id;
      final name = med['name'] as String? ?? 'Medication';
      final dosage = med['dosage'] as String? ?? '';
      final condition = illnessNames[illnessId] ?? '';
      final times = med['scheduledTimes'] as List? ?? [];

      final medStartRaw = med['startDate'] ?? med['createdAt'];
      DateTime medStart = today.subtract(const Duration(days: 30));
      if (medStartRaw is Timestamp) {
        medStart = medStartRaw.toDate();
      } else if (medStartRaw is String) {
        medStart = DateTime.tryParse(medStartRaw) ?? medStart;
      }
      final startDay = DateTime(medStart.year, medStart.month, medStart.day);

      for (var day = startDay; !day.isAfter(today); day = day.add(const Duration(days: 1))) {
        for (final raw in times) {
          final scheduledAt = MedicationScheduleHelper.parseTimeOnDay(raw.toString(), day);
          if (scheduledAt == null) continue;
          if (!scheduledAt.isBefore(endDayExclusive)) continue;

          final key = doseKey(medId, scheduledAt);
          if (loggedKeys.contains(key)) continue;

          final status = scheduledAt.isBefore(now) ? 'missed' : 'upcoming';

          results.add({
            'medicationId': medId,
            'medicationName': name,
            'dosage': dosage,
            'condition': condition,
            'scheduledTime': scheduledAt,
            'scheduledLabel': raw.toString(),
            'status': status,
          });
        }
      }
    }

    results.sort((a, b) {
      final aTime = a['scheduledTime'] as DateTime;
      final bTime = b['scheduledTime'] as DateTime;
      return bTime.compareTo(aTime);
    });

    return results;
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
      'lateBy': lateBy ?? '',
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
    String medicationDosage = '',
  }) async {
    final payload = {
      'userId': userId,
      'medicationId': medicationId,
      'medicationName': medicationName,
      'medicationDosage': medicationDosage,
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

  /// Stream of ALL reminder logs for the current user scoped to today only.
  /// Uses a scheduledTime range filter — no orderBy, no composite index needed.
  /// Sorting is done in the UI layer.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchAllReminderLogs(String userId) {
    final now = DateTime.now();
    final todayStart = Timestamp.fromDate(DateTime(now.year, now.month, now.day));
    final todayEnd = Timestamp.fromDate(
        DateTime(now.year, now.month, now.day, 23, 59, 59));
    return _col
        .where('userId', isEqualTo: userId)
        .where('scheduledTime', isGreaterThanOrEqualTo: todayStart)
        .where('scheduledTime', isLessThanOrEqualTo: todayEnd)
        .snapshots();
  }

  /// Stream filtered by status for the current user, scoped to today only.
  /// Uses a scheduledTime range filter — no orderBy, no composite index needed.
  /// Sorting is done in the UI layer.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchReminderLogsByStatus(
    String userId,
    String status,
  ) {
    final now = DateTime.now();
    final todayStart = Timestamp.fromDate(DateTime(now.year, now.month, now.day));
    final todayEnd = Timestamp.fromDate(
        DateTime(now.year, now.month, now.day, 23, 59, 59));
    return _col
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: status)
        .where('scheduledTime', isGreaterThanOrEqualTo: todayStart)
        .where('scheduledTime', isLessThanOrEqualTo: todayEnd)
        .snapshots();
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

  /// Returns full dose stats for a period: taken/missed/pending counts and
  /// a per-medication breakdown list, all derived from real reminder logs.
  Future<DoseStats> fetchDoseStats(String userId, {DateTime? start, DateTime? end}) async {
    final medSnap = await _firestore
        .collection(FirebaseCollections.medications)
        .where('userId', isEqualTo: userId)
        .get();
    final illnessSnap = await _firestore
        .collection(FirebaseCollections.illnesses)
        .where('userId', isEqualTo: userId)
        .get();
    final logSnap = await _col.where('userId', isEqualTo: userId).get();

    final allEntries = _buildFullDoseHistory(
      medSnap,
      illnessSnap,
      logSnap,
    );

    var taken = 0;
    var missed = 0;
    var pending = 0;

    // med name → {taken, missed, pending}
    final medMap = <String, Map<String, int>>{};

    for (final d in allEntries) {
      final status = (d['status'] as String? ?? '').toLowerCase();
      final medName = d['medicationName'] as String? ?? d['name'] as String? ?? 'Medication';

      medMap.putIfAbsent(medName, () => {'taken': 0, 'missed': 0, 'pending': 0});

      if (status == 'confirmed' || status == 'taken') {
        taken++;
        medMap[medName]!['taken'] = medMap[medName]!['taken']! + 1;
      } else if (status == 'missed' || status == 'skipped') {
        missed++;
        medMap[medName]!['missed'] = medMap[medName]!['missed']! + 1;
      } else {
        pending++;
        medMap[medName]!['pending'] = medMap[medName]!['pending']! + 1;
      }
    }

    final total = taken + missed + pending;

    final medStats = medMap.entries.map((e) {
      final t = e.value['taken']! + e.value['missed']! + e.value['pending']!;
      final pct = t == 0 ? 0 : ((e.value['taken']! / t) * 100).round();
      return MedStat(
        name: e.key,
        taken: e.value['taken']!,
        missed: e.value['missed']!,
        pending: e.value['pending']!,
        total: t,
        adherencePct: pct,
      );
    }).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return DoseStats(
      taken: taken,
      missed: missed,
      pending: pending,
      total: total,
      medStats: medStats,
    );
  }

  // ---------------------------------------------------------------------------
  // Adaptive reminder logic
  // ---------------------------------------------------------------------------

  /// Runs the daily adaptive reminder logic for [userId].
  ///
  /// Should be called once per dashboard load. Runs silently — all errors are
  /// caught internally and never surfaced to the user.
  Future<void> runAdaptiveLogic(String userId) async {
    try {
      // 1. Fetch all active medications for this user.
      final snap = await _firestore
          .collection(FirebaseCollections.medications)
          .where('userId', isEqualTo: userId)
          .where('active', isEqualTo: true)
          .get();

      final adherenceService = AdherenceService(firestore: _firestore);
      final notificationService = NotificationService.instance;

      for (final doc in snap.docs) {
        try {
          final data = doc.data();
          final medId = doc.id;
          final illnessId = data['illnessId'] as String? ?? '';
          final dosage = data['dosage'] as String? ?? '';
          final mealTiming = data['mealTiming'] as String? ?? 'anytime';
          final illnessName = await _getIllnessName(illnessId);

          // ── COLD START CHECK ────────────────────────────────────────────
          // Skip medications that are less than 7 days old.
          final createdAtRaw = data['createdAt'];
          DateTime createdAt;
          if (createdAtRaw is Timestamp) {
            createdAt = createdAtRaw.toDate();
          } else if (createdAtRaw is String) {
            createdAt = DateTime.tryParse(createdAtRaw) ?? DateTime.now();
          } else {
            createdAt = DateTime.now();
          }

          if (DateTime.now().difference(createdAt).inDays < 7) continue;

          // ── CALCULATE SCORE ─────────────────────────────────────────────
          final score =
              await adherenceService.calculate7DayScore(userId, medId);

          final medRef = _firestore
              .collection(FirebaseCollections.medications)
              .doc(medId);

          final scheduledTimes =
              List<String>.from(data['scheduledTimes'] as List? ?? []);
          final originalScheduledTimes = List<String>.from(
              data['originalScheduledTimes'] as List? ?? []);
          final consecutiveDaysAbove85 =
              data['consecutiveDaysAbove85'] as int? ?? 0;

          if (score < 70.0) {
            // ── ADJUST REMINDERS ──────────────────────────────────────────
            final delay = await adherenceService
                .calculateAverageResponseDelay(userId, medId);

            if (delay > 0) {
              // Save backup of original times if not already saved.
              if (originalScheduledTimes.isEmpty) {
                try {
                  await medRef.update({
                    'originalScheduledTimes': scheduledTimes,
                  });
                } catch (_) {}
              }

              // Shift each time earlier by the average delay.
              final newTimes = scheduledTimes
                  .map((t) => adjustTime(t, delay))
                  .toList();

              // Persist new times and reset streak counter.
              try {
                await medRef.update({
                  'scheduledTimes': newTimes,
                  'consecutiveDaysAbove85': 0,
                });
              } catch (_) {}

              // Reschedule notifications.
              try {
                await notificationService.cancelMedicationReminders(
                  medId,
                  timeCount: scheduledTimes.length + 5,
                );
              } catch (_) {}

              try {
                final name =
                    data['name'] as String? ?? data['title'] as String? ?? 'Medication';
                await notificationService.scheduleMedicationReminders(
                  medicationId: medId,
                  title: name,
                  timeStrings: newTimes,
                  dosage: dosage,
                  condition: illnessName,
                  mealTiming: mealTiming,
                  userId: userId,
                  illnessId: illnessId,
                );
              } catch (_) {}
            }
          } else if (score > 85.0) {
            // ── CHECK RESET ───────────────────────────────────────────────
            final current = consecutiveDaysAbove85;

            if (current >= 2 && originalScheduledTimes.isNotEmpty) {
              // 3rd consecutive day above 85 → restore original times.
              try {
                await medRef.update({
                  'scheduledTimes': originalScheduledTimes,
                  'originalScheduledTimes': [],
                  'consecutiveDaysAbove85': 0,
                });
              } catch (_) {}

              try {
                await notificationService.cancelMedicationReminders(
                  medId,
                  timeCount: scheduledTimes.length + 5,
                );
              } catch (_) {}

              try {
                final name =
                    data['name'] as String? ?? data['title'] as String? ?? 'Medication';
                await notificationService.scheduleMedicationReminders(
                  medicationId: medId,
                  title: name,
                  timeStrings: originalScheduledTimes,
                  dosage: dosage,
                  condition: illnessName,
                  mealTiming: mealTiming,
                  userId: userId,
                  illnessId: illnessId,
                );
              } catch (_) {}
            } else {
              // Increment streak counter.
              try {
                await medRef.update({
                  'consecutiveDaysAbove85': current + 1,
                });
              } catch (_) {}
            }
          } else {
            // ── SCORE BETWEEN 70 AND 85 ───────────────────────────────────
            // Reset streak counter.
            try {
              await medRef.update({
                'consecutiveDaysAbove85': 0,
              });
            } catch (_) {}
          }
        } catch (_) {
          // Never let a single medication failure stop the rest.
          continue;
        }
      }
    } catch (_) {
      // Top-level silent catch — never surface to the user.
    }
  }

  /// Shifts [timeStr] (format "HH:mm") earlier by [delayMinutes].
  ///
  /// Handles midnight wrap-around. Example: `adjustTime("08:00", 25.0)`
  /// returns `"07:35"`.
  String adjustTime(String timeStr, double delayMinutes) {
    final parts = timeStr.trim().split(':');
    if (parts.length != 2) return timeStr;
    final hours = int.tryParse(parts[0]) ?? 0;
    final minutes = int.tryParse(parts[1]) ?? 0;

    final totalMins = hours * 60 + minutes;
    var newTotalMins = totalMins - delayMinutes.round();
    if (newTotalMins < 0) newTotalMins += 1440; // wrap 24 h

    final newHours = newTotalMins ~/ 60;
    final newMins = newTotalMins % 60;
    return '${newHours.toString().padLeft(2, '0')}:${newMins.toString().padLeft(2, '0')}';
  }

  // ---------------------------------------------------------------------------
  // Missed dose detection
  // ---------------------------------------------------------------------------

  /// Writes a single reminder log entry to Firestore.
  ///
  /// [responseLatencyMinutes] is derived automatically from [actualResponseTime]
  /// when provided. All fields are nullable-safe.
  Future<void> logReminderAction({
    required String userId,
    required String medicationId,
    required String illnessId,
    required DateTime scheduledTime,
    required String status,
    DateTime? actualResponseTime,
    String medicationName = '',
    String medicationDosage = '',
  }) async {
    try {
      await _col.add({
        'userId': userId,
        'medicationId': medicationId,
        'medicationName': medicationName,
        'medicationDosage': medicationDosage,
        'illnessId': illnessId,
        'scheduledTime': Timestamp.fromDate(scheduledTime),
        if (actualResponseTime != null) ...{
          'actualResponseTime': Timestamp.fromDate(actualResponseTime),
          'responseLatencyMinutes': actualResponseTime
              .difference(scheduledTime)
              .inMinutes
              .toDouble(),
        },
        'status': status,
        'createdAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (_) {}
  }

  /// Scans today's schedule for every active medication and auto-logs any
  /// dose that was due more than 60 minutes ago with no existing log.
  Future<void> checkMissedReminders(String userId) async {
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);

      final medSnap = await _firestore
          .collection(FirebaseCollections.medications)
          .where('userId', isEqualTo: userId)
          .where('active', isEqualTo: true)
          .get();

      for (final medDoc in medSnap.docs) {
        final data = medDoc.data();
        final medId = medDoc.id;
        final medName = data['name'] as String? ?? '';
        final medDosage = data['dosage'] as String? ?? '';
        final illnessId = data['illnessId'] as String? ?? '';
        final times = List<String>.from(data['scheduledTimes'] as List? ?? []);

        if (illnessId.isNotEmpty) {
          try {
            final illnessDoc = await _firestore
                .collection(FirebaseCollections.illnesses)
                .doc(illnessId)
                .get();
            final illnessStatus =
                illnessDoc.data()?['status'] as String? ?? 'active';
            if (illnessStatus == 'completed') continue;
          } catch (_) {
            continue;
          }
        }

        for (final timeStr in times) {
          final parsed = _parseTimeString(timeStr);
          if (parsed == null) continue;

          final scheduledDt = DateTime(
            todayStart.year,
            todayStart.month,
            todayStart.day,
            parsed.$1,
            parsed.$2,
          );

          // Only auto-log if dose was due more than 5 minutes ago.
          if (!scheduledDt.isBefore(now.subtract(const Duration(minutes: 5)))) {
            continue;
          }

          // Check if a log already exists within ±5 minutes of scheduled time.
          final existingLog = await _col
              .where('userId', isEqualTo: userId)
              .where('medicationId', isEqualTo: medId)
              .where('scheduledTime',
                  isGreaterThanOrEqualTo: Timestamp.fromDate(
                      scheduledDt.subtract(const Duration(minutes: 5))))
              .where('scheduledTime',
                  isLessThanOrEqualTo: Timestamp.fromDate(
                      scheduledDt.add(const Duration(minutes: 5))))
              .limit(1)
              .get();

          if (existingLog.docs.isNotEmpty) continue;

          final condition = await _getIllnessName(illnessId);

          // Format the display time for the alert message (e.g. "8:00 AM").
          final displayTime = DateFormat.jm().format(scheduledDt);

          try {
            await _col.add({
              'userId': userId,
              'medicationId': medId,
              'medicationName': medName,
              'medicationDosage': medDosage,
              'illnessId': illnessId,
              'condition': condition,
              'scheduledTime': Timestamp.fromDate(scheduledDt),
              'actualResponseTime': null,
              'responseLatencyMinutes': null,
              'status': 'missed',
              'createdAt': Timestamp.fromDate(now),
            });
          } catch (_) {
            continue;
          }

          await _createMissedDoseAlert(
            userId,
            medName,
            medDosage,
            displayTime,
          );
        }
      }
    } catch (_) {}
  }

  Future<String> _getIllnessName(String illnessId) async {
    if (illnessId.isEmpty) return '';
    try {
      final doc = await _firestore
          .collection(FirebaseCollections.illnesses)
          .doc(illnessId)
          .get();
      return doc.data()?['illnessName'] as String? ?? '';
    } catch (_) {
      return '';
    }
  }

  Future<void> _createMissedDoseAlert(
    String userId,
    String medName,
    String medDosage,
    String displayTime,
  ) async {
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);

      // Avoid duplicate alerts for the same medication+time within the same day.
      final existing = await _firestore
          .collection(FirebaseCollections.alerts)
          .where('userId', isEqualTo: userId)
          .where('type', isEqualTo: 'missed_dose')
          .where('createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
          .get();

      final dosageStr = medDosage.isNotEmpty ? ' $medDosage' : '';
      final message =
          'You missed your $displayTime dose of $medName$dosageStr';

      final alreadyExists =
          existing.docs.any((d) => (d.data()['message'] as String? ?? '') == message);
      if (alreadyExists) return;

      await _firestore.collection(FirebaseCollections.alerts).add({
        'userId': userId,
        'type': 'missed_dose',
        'message': message,
        'read': false,
        'createdAt': Timestamp.fromDate(now),
      });
    } catch (_) {}
  }

  (int, int)? _parseTimeString(String timeStr) {
    final lower = timeStr.toLowerCase().trim();
    final match =
        RegExp(r'(\d{1,2}):(\d{2})\s*(am|pm)?').firstMatch(lower);
    if (match == null) return null;
    var hour = int.tryParse(match.group(1)!) ?? 0;
    final minute = int.tryParse(match.group(2)!) ?? 0;
    final ampm = match.group(3);
    if (ampm == 'pm' && hour < 12) hour += 12;
    if (ampm == 'am' && hour == 12) hour = 0;
    return (hour, minute);
  }

  // ---------------------------------------------------------------------------
  // Notification action handler
  // ---------------------------------------------------------------------------

  /// Processes a notification action tap (Taken / Snooze / Skip).
  ///
  /// Call this from your notification callback with the decoded payload fields.
  /// Lives in [ReminderService] (not [NotificationService]) to avoid a circular
  /// import — reminder_service already imports notification_service.
  ///
  /// [actionId]           — `'taken'`, `'snoozed'`, or `'skipped'`
  /// [scheduledTimeMs]    — `scheduledTime.millisecondsSinceEpoch` from payload
  /// [snoozeDurationMinutes] — default 15
  static Future<void> handleNotificationAction({
    required String actionId,
    required String userId,
    required String medicationId,
    required String illnessId,
    required int scheduledTimeMs,
    int snoozeDurationMinutes = 15,
  }) async {
    final reminder = ReminderService();
    final adherence = AdherenceService();
    final now = DateTime.now();
    final scheduledTime = DateTime.fromMillisecondsSinceEpoch(scheduledTimeMs);

    switch (actionId) {
      case 'taken':
        try {
          await reminder.logReminderAction(
            userId: userId,
            medicationId: medicationId,
            illnessId: illnessId,
            scheduledTime: scheduledTime,
            status: 'confirmed',
            actualResponseTime: now,
          );
        } catch (_) {}
        try {
          await adherence.decrementStock(medicationId, userId);
        } catch (_) {}
        return;

      case 'snoozed':
        try {
          await reminder.logReminderAction(
            userId: userId,
            medicationId: medicationId,
            illnessId: illnessId,
            scheduledTime: scheduledTime,
            status: 'snoozed',
            actualResponseTime: now,
          );
        } catch (_) {}
        // Reschedule for now + snooze duration.
        try {
          await NotificationService.instance.scheduleSnooze(
            medicationId: medicationId,
            snoozeDurationMinutes: snoozeDurationMinutes,
          );
        } catch (_) {}
        return;

      case 'skipped':
        try {
          await reminder.logReminderAction(
            userId: userId,
            medicationId: medicationId,
            illnessId: illnessId,
            scheduledTime: scheduledTime,
            status: 'skipped',
            actualResponseTime: now,
          );
        } catch (_) {}
        return;
    }
  }
  // ---------------------------------------------------------------------------
  // Auto-log missed doses (60-minute threshold)
  // ---------------------------------------------------------------------------

  /// Scans today's schedule and auto-logs any dose that was due more than
  /// 60 minutes ago with no existing reminder log. Also writes a
  /// `missed_dose` alert to the `alerts` collection.
  ///
  /// Call this from the dashboard or any screen on load. All errors are
  /// caught internally — never surfaced to the user.
  Future<void> autoLogMissedDoses(String userId) async {
    try {
      final medsSnapshot = await _firestore
          .collection(FirebaseCollections.medications)
          .where('userId', isEqualTo: userId)
          .where('active', isEqualTo: true)
          .get();

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      for (final medDoc in medsSnapshot.docs) {
        try {
          final data = medDoc.data();
          final medicationId = medDoc.id;
          final medicationName = data['name'] as String? ?? '';
          final dosage = data['dosage'] as String? ?? '';
          final illnessId = data['illnessId'] as String? ?? '';
          final List<dynamic> times = data['scheduledTimes'] as List? ?? [];

          // Skip completed illnesses.
          if (illnessId.isNotEmpty) {
            try {
              final illnessDoc = await _firestore
                  .collection(FirebaseCollections.illnesses)
                  .doc(illnessId)
                  .get();
              final illnessStatus =
                  illnessDoc.data()?['status'] as String? ?? 'active';
              if (illnessStatus == 'completed') continue;
            } catch (_) {
              continue;
            }
          }

          for (final timeRaw in times) {
            try {
              final timeStr = timeRaw.toString();
              final parsed = _parseTimeString(timeStr);
              if (parsed == null) continue;

              final scheduledDateTime = DateTime(
                today.year,
                today.month,
                today.day,
                parsed.$1,
                parsed.$2,
              );

              // Only check times that are more than 60 minutes in the past.
              final minutesPast =
                  now.difference(scheduledDateTime).inMinutes;
              if (minutesPast < 60) continue;
              if (scheduledDateTime.isBefore(today)) continue;

              // Check if a log already exists within ±5 minutes.
              final existingLog = await _col
                  .where('userId', isEqualTo: userId)
                  .where('medicationId', isEqualTo: medicationId)
                  .where(
                    'scheduledTime',
                    isGreaterThanOrEqualTo: Timestamp.fromDate(
                        scheduledDateTime.subtract(
                            const Duration(minutes: 5))),
                  )
                  .where(
                    'scheduledTime',
                    isLessThanOrEqualTo: Timestamp.fromDate(
                        scheduledDateTime.add(const Duration(minutes: 5))),
                  )
                  .limit(1)
                  .get();

              if (existingLog.docs.isNotEmpty) continue;

              // Log as missed.
              await _col.add({
                'userId': userId,
                'medicationId': medicationId,
                'illnessId': illnessId,
                'medicationName': medicationName,
                'medicationDosage': dosage,
                'scheduledTime': Timestamp.fromDate(scheduledDateTime),
                'actualResponseTime': null,
                'responseLatencyMinutes': null,
                'status': 'missed',
                'createdAt': Timestamp.fromDate(DateTime.now()),
              });

              // Create a missed-dose alert (deduped by message content).
              final displayTime =
                  '${parsed.$1.toString().padLeft(2, '0')}:${parsed.$2.toString().padLeft(2, '0')}';
              await _createMissedDoseAlert(
                userId,
                medicationName,
                dosage,
                displayTime,
              );

              debugPrint(
                  'Auto-logged missed dose: $medicationName at $timeStr');
            } catch (_) {
              continue;
            }
          }
        } catch (_) {
          continue;
        }
      }
    } catch (e) {
      debugPrint('Error auto-logging missed doses: $e');
    }
  }
}

/// Aggregated dose statistics for a reporting period.
class DoseStats {
  const DoseStats({
    required this.taken,
    required this.missed,
    required this.pending,
    required this.total,
    required this.medStats,
  });
  final int taken;
  final int missed;
  final int pending;
  final int total;
  final List<MedStat> medStats;

  bool get isEmpty => total == 0;
}

/// Per-medication adherence stats.
class MedStat {
  const MedStat({
    required this.name,
    required this.taken,
    required this.missed,
    required this.pending,
    required this.total,
    required this.adherencePct,
  });
  final String name;
  final int taken;
  final int missed;
  final int pending;
  final int total;
  final int adherencePct;
}
