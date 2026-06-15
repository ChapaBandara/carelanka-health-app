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

      final confirmed = snap.docs.where((doc) {
        final status = (doc.data()['status'] as String? ?? '').toLowerCase();
        return status == 'confirmed' || status == 'taken';
      }).length;

      return (confirmed / total) * 100;
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

      final confirmed = snap.docs.where((doc) {
        final status = (doc.data()['status'] as String? ?? '').toLowerCase();
        return status == 'confirmed' || status == 'taken';
      }).length;

      return AdherenceResult(
        score: (confirmed / total) * 100,
        confirmed: confirmed,
        total: total,
      );
    } catch (_) {
      return const AdherenceResult(score: 100.0, confirmed: 0, total: 0);
    }
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
    return calculateStockDaysRemaining(stockCount, frequency) <= threshold;
  }
  // ---------------------------------------------------------------------------
  // Low-stock warning system
  // ---------------------------------------------------------------------------

  /// Decrements [medicationId]'s stockCount by 1 and triggers a low-stock
  /// check. Does nothing if the current stock is already 0.
  Future<void> decrementStock(String medicationId, String userId) async {
    try {
      final ref = _firestore
          .collection(FirebaseCollections.medications)
          .doc(medicationId);
      final snap = await ref.get();
      if (!snap.exists) return;

      final currentStock = snap.data()?['stockCount'] as int? ?? 0;
      final newStock = currentStock - 1;
      if (newStock < 0) return;

      await ref.update({'stockCount': newStock});
      await checkAndAlertLowStock(medicationId, userId);
    } catch (_) {}
  }

  /// Checks whether [medicationId] has fallen at or below its low-stock
  /// threshold. If so, creates a Firestore alert (deduplicated to one per day)
  /// and fires a local notification.
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
      final frequencyStr = data['frequency'] as String? ?? 'Once daily';
      final threshold = data['lowStockThreshold'] as int? ?? 0;
      final name = data['name'] as String? ?? data['title'] as String? ?? 'Medication';

      // threshold == 0 means the user disabled stock reminders.
      if (threshold == 0) return;

      final frequency = _doseCountForFrequency(frequencyStr);
      final daysRemaining = calculateStockDaysRemaining(stockCount, frequency);

      if (daysRemaining > threshold) return;

      // Deduplicate: only create one alert per medication per calendar day.
      final now = DateTime.now();
      final todayMidnight = DateTime(now.year, now.month, now.day);
      try {
        final alertsSnap = await _firestore
            .collection(FirebaseCollections.alerts)
            .where('userId', isEqualTo: userId)
            .where('type', isEqualTo: 'general')
            .where('createdAt',
                isGreaterThanOrEqualTo: Timestamp.fromDate(todayMidnight))
            .get();

        final alreadyAlerted = alertsSnap.docs.any((doc) {
          final msg = doc.data()['message'] as String? ?? '';
          return msg.contains(name);
        });
        if (alreadyAlerted) return;
      } catch (_) {}

      // Create Firestore alert.
      final message = '$name is running low. $daysRemaining day${daysRemaining == 1 ? '' : 's'} '
          'of supply remaining. Visit your doctor for a renewal prescription.';
      try {
        await _firestore.collection(FirebaseCollections.alerts).add({
          'userId': userId,
          'type': 'general',
          'message': message,
          'read': false,
          'createdAt': Timestamp.fromDate(now),
        });
      } catch (_) {}

      // Fire local notification.
      try {
        await NotificationService.instance.showLowStockNotification(
          title: 'Medication Running Low',
          body: '$name — $daysRemaining day${daysRemaining == 1 ? '' : 's'} remaining',
        );
      } catch (_) {}
    } catch (_) {}
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

  /// Converts a frequency label (as stored in Firestore) to a numeric
  /// doses-per-day count, mirroring the logic in AddMedicationScreen.
  int _doseCountForFrequency(String frequency) {
    switch (frequency) {
      case 'Once daily':
        return 1;
      case 'Three times daily':
        return 3;
      case 'Four times daily':
        return 4;
      default:
        return 2; // 'Twice daily' and any unknown value
    }
  }
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
