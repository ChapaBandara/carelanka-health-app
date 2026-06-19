import 'dart:async';

import 'package:carelanka_app/core/firebase/firebase_collections.dart';
import 'package:carelanka_app/core/utils/medication_schedule_helper.dart';
import 'package:carelanka_app/models/daily_dose_item.dart';
import 'package:carelanka_app/services/adherence_service.dart';
import 'package:carelanka_app/services/notification_service.dart';
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
  }) async {
    try {
      await _col.add({
        'userId': userId,
        'medicationId': medicationId,
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
      final medsSnap = await _firestore
          .collection(FirebaseCollections.medications)
          .where('userId', isEqualTo: userId)
          .where('active', isEqualTo: true)
          .get();

      final now = DateTime.now();
      final todayBase = DateTime(now.year, now.month, now.day);

      for (final medDoc in medsSnap.docs) {
        try {
          final data = medDoc.data();
          final medId = medDoc.id;
          final illnessId = data['illnessId'] as String? ?? '';
          final medName = data['name'] as String? ?? 'Medication';
          final dosage = data['dosage'] as String? ?? '';
          final times =
              List<String>.from(data['scheduledTimes'] as List? ?? []);

          for (final timeStr in times) {
            try {
              // Parse both "HH:mm" (24-hr) and "h:mm a" (12-hr AM/PM).
              final scheduledDateTime =
                  _parseScheduledTime(timeStr.trim(), todayBase);
              if (scheduledDateTime == null) continue;

              // Only consider doses that fired more than 60 minutes ago.
              if (now.difference(scheduledDateTime).inMinutes <= 60) continue;

              // Check for any existing log within ±5 minutes.
              final windowStart =
                  scheduledDateTime.subtract(const Duration(minutes: 5));
              final windowEnd =
                  scheduledDateTime.add(const Duration(minutes: 5));

              final logsSnap = await _col
                  .where('userId', isEqualTo: userId)
                  .where('medicationId', isEqualTo: medId)
                  .where('scheduledTime',
                      isGreaterThanOrEqualTo:
                          Timestamp.fromDate(windowStart))
                  .where('scheduledTime',
                      isLessThanOrEqualTo: Timestamp.fromDate(windowEnd))
                  .get();

              if (logsSnap.docs.isNotEmpty) continue;

              // No log found — record as missed.
              await logReminderAction(
                userId: userId,
                medicationId: medId,
                illnessId: illnessId,
                scheduledTime: scheduledDateTime,
                status: 'missed',
              );

              await createMissedDoseAlert(
                userId: userId,
                medicationName: medName,
                dosage: dosage,
                scheduledTime: scheduledDateTime,
              );
            } catch (_) {
              continue;
            }
          }
        } catch (_) {
          continue;
        }
      }
    } catch (_) {}
  }

  /// Creates a Firestore alert and fires a local notification for a missed dose.
  Future<void> createMissedDoseAlert({
    required String userId,
    required String medicationName,
    required String dosage,
    required DateTime scheduledTime,
  }) async {
    final timeStr = DateFormat('h:mm a').format(scheduledTime);
    final doseLabel =
        [medicationName, if (dosage.isNotEmpty) dosage].join(' ');

    try {
      await _firestore.collection(FirebaseCollections.alerts).add({
        'userId': userId,
        'type': 'missed',
        'message': 'You missed your $timeStr dose of $doseLabel',
        'read': false,
        'createdAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (_) {}

    try {
      await NotificationService.instance.showMissedDoseNotification(
        title: 'Missed Dose',
        body: 'You missed your $medicationName dose scheduled at $timeStr',
      );
    } catch (_) {}
  }

  /// Parses a time string in either "HH:mm" (24-hr) or "h:mm a" (12-hr)
  /// format and returns a [DateTime] on [day].
  DateTime? _parseScheduledTime(String timeStr, DateTime day) {
    // Try 12-hr format first: "8:00 AM", "12:30 PM"
    try {
      final parsed = DateFormat('h:mm a').parse(timeStr);
      return DateTime(day.year, day.month, day.day, parsed.hour, parsed.minute);
    } catch (_) {}

    // Fall back to 24-hr "HH:mm": "08:00", "20:30"
    final parts = timeStr.split(':');
    if (parts.length == 2) {
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h != null && m != null) {
        return DateTime(day.year, day.month, day.day, h, m);
      }
    }
    return null;
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
