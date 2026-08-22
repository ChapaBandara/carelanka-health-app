import 'package:carelanka_app/core/firebase/firebase_collections.dart';
import 'package:carelanka_app/services/notification_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Provides medication adherence calculations derived from [reminder_logs].
///
/// All Firestore calls are wrapped in try-catch so the app never crashes if
/// Firestore is unavailable — callers receive sensible default values instead.
class AdherenceService {
  AdherenceService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection(FirebaseCollections.reminderLogs);

  // ---------------------------------------------------------------------------
  // 7-day adherence score for a specific medication
  // ---------------------------------------------------------------------------

  /// Returns the adherence percentage (0–100) for [medicationId] over the
  /// last 7 days.
  ///
  /// Formula: (confirmed / total) × 100
  /// Returns 100.0 when there are no logs (no data = no missed doses).
  Future<double> calculate7DayScore(
    String userId,
    String medicationId,
  ) async {
    try {
      final since = DateTime.now().subtract(const Duration(days: 7));
      final snap = await _col
          .where('userId', isEqualTo: userId)
          .where('medicationId', isEqualTo: medicationId)
          .where('scheduledTime',
              isGreaterThanOrEqualTo: Timestamp.fromDate(since))
          .get();

      final total = snap.docs.length;
      if (total == 0) return 100.0;

      final rawConfirmed = snap.docs.where((doc) {
        final status = (doc.data()['status'] as String? ?? '').toLowerCase();
        return status == 'confirmed' || status == 'taken';
      }).length;
      final confirmed = rawConfirmed.clamp(0, total);

      return ((confirmed / total) * 100).clamp(0.0, 100.0);
    } catch (_) {
      return 100.0;
    }
  }

  // ---------------------------------------------------------------------------
  // Overall 7-day adherence score across all medications
  // ---------------------------------------------------------------------------

  /// Returns the overall adherence percentage (0–100) for [userId] over the
  /// last 7 days, across all medications.
  ///
  /// Also returns the raw confirmed and total counts via [AdherenceResult].
  Future<AdherenceResult> calculateOverallScore(String userId) async {
    try {
      final since = DateTime.now().subtract(const Duration(days: 7));
      final snap = await _col
          .where('userId', isEqualTo: userId)
          .where('scheduledTime',
              isGreaterThanOrEqualTo: Timestamp.fromDate(since))
          .get();

      final total = snap.docs.length;
      if (total == 0) return const AdherenceResult(score: 100.0, confirmed: 0, total: 0);

      final rawConfirmed = snap.docs.where((doc) {
        final status = (doc.data()['status'] as String? ?? '').toLowerCase();
        return status == 'confirmed' || status == 'taken';
      }).length;
      final confirmed = rawConfirmed.clamp(0, total);
      final score = ((confirmed / total) * 100).clamp(0.0, 100.0);

      return AdherenceResult(
        score: score,
        confirmed: confirmed,
        total: total,
      );
    } catch (_) {
      return const AdherenceResult(score: 100.0, confirmed: 0, total: 0);
    }
  }

  /// Real-time stream version of [calculateOverallScore].
  ///
  /// Deduplicates reminder_log documents by medicationId + scheduledHour +
  /// scheduledMinute within the 7-day window before computing the score, so
  /// duplicate logs for the same dose do not inflate the total count.
  Stream<AdherenceResult> watchOverallScore(String userId) {
    final since = DateTime.now().subtract(const Duration(days: 7));
    return _col
        .where('userId', isEqualTo: userId)
        .where('scheduledTime',
            isGreaterThanOrEqualTo: Timestamp.fromDate(since))
        .snapshots()
        .map((snap) {
      try {
        // Dedup: keep the highest-priority status per unique dose slot.
        // Priority: confirmed=0 > snoozed=1 > skipped=2 > missed=3 > pending=4
        int priority(String s) {
          switch (s) {
            case 'confirmed':
            case 'taken':
              return 0;
            case 'snoozed':
              return 1;
            case 'skipped':
              return 2;
            case 'missed':
              return 3;
            default:
              return 4;
          }
        }

        final best = <String, String>{};
        for (final doc in snap.docs) {
          final d = doc.data();
          final medId = d['medicationId'] as String? ?? '';
          final scheduled = d['scheduledTime'];
          if (scheduled is! Timestamp) continue;
          final dt = scheduled.toDate();
          final key = '${medId}_${dt.hour}_${dt.minute}';
          final status = (d['status'] as String? ?? 'pending').toLowerCase();
          if (!best.containsKey(key) ||
              priority(status) < priority(best[key]!)) {
            best[key] = status;
          }
        }

        if (best.isEmpty) {
          return const AdherenceResult(score: 100.0, confirmed: 0, total: 0);
        }

        final total = best.length;
        final rawConfirmed = best.values.where((s) {
          return s == 'confirmed' || s == 'taken';
        }).length;
        final confirmed = rawConfirmed.clamp(0, total);
        final score = ((confirmed / total) * 100).clamp(0.0, 100.0);

        return AdherenceResult(
          score: score,
          confirmed: confirmed,
          total: total,
        );
      } catch (_) {
        return const AdherenceResult(score: 100.0, confirmed: 0, total: 0);
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Average response delay
  // ---------------------------------------------------------------------------

  /// Returns the average [responseLatencyMinutes] for confirmed doses of
  /// [medicationId] logged in the last 7 days.
  ///
  /// Returns 0.0 when there are no confirmed logs.
  Future<double> calculateAverageResponseDelay(
    String userId,
    String medicationId,
  ) async {
    try {
      final since = DateTime.now().subtract(const Duration(days: 7));
      final snap = await _col
          .where('userId', isEqualTo: userId)
          .where('medicationId', isEqualTo: medicationId)
          .where('status', isEqualTo: 'confirmed')
          .where('scheduledTime',
              isGreaterThanOrEqualTo: Timestamp.fromDate(since))
          .get();

      if (snap.docs.isEmpty) return 0.0;

      final totalLatency = snap.docs.fold<int>(0, (acc, doc) {
        final latency = doc.data()['responseLatencyMinutes'] as int? ?? 0;
        return acc + latency;
      });

      return totalLatency / snap.docs.length;
    } catch (_) {
      return 0.0;
    }
  }

  // ---------------------------------------------------------------------------
  // Insight text
  // ---------------------------------------------------------------------------

  /// Maps an adherence [score] to a human-readable insight string.
  String generateInsightText(double score) {
    if (score >= 90) {
      return 'Excellent consistency. Keep maintaining this routine.';
    } else if (score >= 70) {
      return 'Good progress. Try to avoid missing evening doses.';
    } else if (score >= 50) {
      return 'Your adherence needs attention. Adaptive reminders have been '
          'adjusted to better match your routine.';
    } else {
      return 'Critical: You are missing more than half your doses. '
          'Please consult your doctor.';
    }
  }

  // ---------------------------------------------------------------------------
  // Stock helpers (pure, no Firestore)
  // ---------------------------------------------------------------------------

  /// Returns the number of days of stock remaining.
  ///
  /// [frequency] is the number of doses per day. Returns 999 when [frequency]
  /// is zero to indicate an effectively unlimited supply.
  int calculateStockDaysRemaining(int stockCount, int frequency) {
    if (frequency == 0) return 999;
    return (stockCount / frequency).floor();
  }

  /// Returns true when the remaining stock days fall at or below [threshold].
  bool isStockLow(int stockCount, int frequency, int threshold) {
    if (threshold <= 0) return false;
    return calculateStockDaysRemaining(stockCount, frequency) <= threshold;
  }

  // ---------------------------------------------------------------------------
  // Low-stock warning system
  // ---------------------------------------------------------------------------

  /// Decrements [medicationId]'s stockCount by 1 and triggers a low-stock
  /// check. Clamps stock at 0.
  Future<void> decrementStock(String medicationId, String userId) async {
    try {
      final ref = _firestore
          .collection(FirebaseCollections.medications)
          .doc(medicationId);
      final snap = await ref.get();
      if (!snap.exists) return;

      final currentStock = snap.data()?['stockCount'] as int? ?? 0;
      final newStock = (currentStock - 1).clamp(0, 999999);

      await ref.update({'stockCount': newStock});
      await checkAndAlertLowStock(medicationId, userId);
    } catch (_) {}
  }

  /// Checks whether [medicationId] has fallen at or below its low-stock
  /// threshold. If so, creates a Firestore alert (deduplicated to one per
  /// medication per 7 days) and fires a local notification.
  Future<void> checkAndAlertLowStock(
      String medicationId, String userId) async {
    try {
      final medRef = _firestore
          .collection(FirebaseCollections.medications)
          .doc(medicationId);
      final medSnap = await medRef.get();
      if (!medSnap.exists) return;

      final data = medSnap.data()!;
      final stockCount = data['stockCount'] as int? ?? 0;
      final threshold = data['lowStockThreshold'] as int? ?? 0;
      final name = data['name'] as String? ?? data['title'] as String? ?? 'Medication';
      final illnessId = data['illnessId'] as String? ?? '';

      // threshold <= 0 means the user disabled stock reminders.
      if (threshold <= 0) return;

      final scheduledTimes = List<String>.from(data['scheduledTimes'] as List? ?? []);
      final frequency = data['frequency'] as String? ?? '';
      final dosesPerDay = scheduledTimes.isNotEmpty
          ? scheduledTimes.length
          : _parseFrequencyCount(frequency);

      final daysRemaining = stockCount / dosesPerDay;

      if (daysRemaining > threshold) return;

      // Deduplicate: only create one low-stock alert per medication per 7 days.
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
      try {
        final existingSnap = await _firestore
            .collection(FirebaseCollections.alerts)
            .where('userId', isEqualTo: userId)
            .where('medicationId', isEqualTo: medicationId)
            .get();

        final alreadyAlerted = existingSnap.docs.any((doc) {
          final d = doc.data();
          if (d['type'] != 'low_stock') return false;
          final created = d['createdAt'] as Timestamp?;
          if (created == null) return false;
          return created.toDate().isAfter(sevenDaysAgo);
        });

        if (alreadyAlerted) return;
      } catch (_) {}

      // Create Firestore alert.
      final now = DateTime.now();
      final daysRemainingInt = daysRemaining.floor();
      final message = '$name is running low. $daysRemainingInt day${daysRemainingInt == 1 ? '' : 's'} '
          'of supply remaining. Visit your doctor for a renewal prescription.';
      try {
        await _firestore.collection(FirebaseCollections.alerts).add({
          'userId': userId,
          'type': 'low_stock',
          'medicationId': medicationId,
          'medicationName': name,
          'illnessId': illnessId,
          'message': message,
          'read': false,
          'createdAt': Timestamp.fromDate(now),
        });
      } catch (_) {}

      // Fire local notification.
      try {
        await NotificationService.instance.showLowStockNotification(
          title: 'Medication Running Low',
          body: '$name — $daysRemainingInt day${daysRemainingInt == 1 ? '' : 's'} remaining',
        );
      } catch (_) {}
    } catch (_) {}
  }

  int _parseFrequencyCount(String frequency) {
    final f = frequency.toLowerCase();
    if (f.contains('once') || f.contains('1')) return 1;
    if (f.contains('three') || f.contains('3')) return 3;
    if (f.contains('four') || f.contains('4')) return 4;
    return 2;
  }

  /// Checks stock levels for all active medications belonging to [userId]
  /// and fires alerts where needed.
  Future<void> checkAllMedicationsStock(String userId) async {
    try {
      final snap = await _firestore
          .collection(FirebaseCollections.medications)
          .where('userId', isEqualTo: userId)
          .where('active', isEqualTo: true)
          .get();

      for (final doc in snap.docs) {
        try {
          await checkAndAlertLowStock(doc.id, userId);
        } catch (_) {}
      }
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------


}

// ---------------------------------------------------------------------------
// Result model
// ---------------------------------------------------------------------------

/// Carries the overall adherence score together with the raw confirmed and
/// total dose counts, so callers can display both the percentage and the
/// individual numbers without a second query.
class AdherenceResult {
  final double score;
  final int confirmed;
  final int total;

  const AdherenceResult({
    required this.score,
    required this.confirmed,
    required this.total,
  });

  int get scoreInt => score.round().clamp(0, 100);
}
