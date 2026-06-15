import 'package:carelanka_app/core/firebase/firebase_collections.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Tracks doctor-visit frequency and surfaces overdue-checkup alerts.
///
/// All Firestore calls are individually wrapped in try-catch so callers
/// never crash if the database is temporarily unavailable.
class CheckupService {
  CheckupService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  // ---------------------------------------------------------------------------
  // Visit stats
  // ---------------------------------------------------------------------------

  /// Recalculates and persists [lastCheckupDate] and [averageVisitGapDays]
  /// on the user document by inspecting all health records.
  Future<void> updateVisitStats(String userId) async {
    try {
      final snap = await _firestore
          .collection(FirebaseCollections.healthRecords)
          .where('userId', isEqualTo: userId)
          .orderBy('visitDate', descending: true)
          .get();

      if (snap.docs.isEmpty) return;

      // Extract all visit dates that are valid Timestamps.
      final dates = snap.docs
          .map((doc) => doc.data()['visitDate'])
          .whereType<Timestamp>()
          .toList();

      if (dates.isEmpty) return;

      // Persist the most recent visit date.
      final latestVisit = dates.first;
      try {
        await _firestore
            .collection(FirebaseCollections.users)
            .doc(userId)
            .update({'lastCheckupDate': latestVisit});
      } catch (_) {}

      if (dates.length < 2) {
        // Only one record — use the default gap.
        try {
          await _firestore
              .collection(FirebaseCollections.users)
              .doc(userId)
              .update({'averageVisitGapDays': 30});
        } catch (_) {}
        return;
      }

      // Calculate gaps (in days) between consecutive visits.
      final gaps = <int>[];
      for (var i = 0; i < dates.length - 1; i++) {
        final gap = dates[i]
            .toDate()
            .difference(dates[i + 1].toDate())
            .inDays
            .abs();
        gaps.add(gap);
      }

      final averageGap =
          (gaps.reduce((a, b) => a + b) / gaps.length).round();

      try {
        await _firestore
            .collection(FirebaseCollections.users)
            .doc(userId)
            .update({'averageVisitGapDays': averageGap});
      } catch (_) {}
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Overdue check
  // ---------------------------------------------------------------------------

  /// Returns `true` when more days have passed since the last visit than the
  /// user's average gap — i.e. a checkup is overdue.
  Future<bool> isCheckupOverdue(String userId) async {
    try {
      final doc = await _firestore
          .collection(FirebaseCollections.users)
          .doc(userId)
          .get();
      if (!doc.exists) return false;

      final data = doc.data()!;
      final lastRaw = data['lastCheckupDate'];
      if (lastRaw == null) return false;

      final lastCheckupDate = (lastRaw as Timestamp).toDate();
      final averageVisitGapDays =
          data['averageVisitGapDays'] as int? ?? 30;

      final daysSince =
          DateTime.now().difference(lastCheckupDate).inDays;
      return daysSince > averageVisitGapDays;
    } catch (_) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Days since last visit
  // ---------------------------------------------------------------------------

  /// Returns the number of days elapsed since the user's last recorded visit.
  /// Returns 0 when no visit date is on record.
  Future<int> getDaysSinceLastVisit(String userId) async {
    try {
      final doc = await _firestore
          .collection(FirebaseCollections.users)
          .doc(userId)
          .get();
      if (!doc.exists) return 0;

      final lastRaw = doc.data()?['lastCheckupDate'];
      if (lastRaw == null) return 0;

      final lastCheckupDate = (lastRaw as Timestamp).toDate();
      return DateTime.now().difference(lastCheckupDate).inDays;
    } catch (_) {
      return 0;
    }
  }

  // ---------------------------------------------------------------------------
  // Alert creation
  // ---------------------------------------------------------------------------

  /// Creates a checkup alert in Firestore if the user is overdue and no alert
  /// has already been created today. Deduplicated to one alert per day.
  Future<void> createCheckupAlertIfNeeded(String userId) async {
    try {
      final overdue = await isCheckupOverdue(userId);
      if (!overdue) return;

      final daysSince = await getDaysSinceLastVisit(userId);

      // Deduplicate — one checkup alert per calendar day.
      final now = DateTime.now();
      final todayMidnight = DateTime(now.year, now.month, now.day);
      try {
        final existing = await _firestore
            .collection(FirebaseCollections.alerts)
            .where('userId', isEqualTo: userId)
            .where('type', isEqualTo: 'checkup')
            .where('createdAt',
                isGreaterThanOrEqualTo: Timestamp.fromDate(todayMidnight))
            .get();
        if (existing.docs.isNotEmpty) return;
      } catch (_) {}

      try {
        await _firestore.collection(FirebaseCollections.alerts).add({
          'userId': userId,
          'type': 'checkup',
          'message':
              'You have not visited a doctor in $daysSince days. '
              'Consider scheduling a checkup.',
          'read': false,
          'createdAt': Timestamp.fromDate(now),
        });
      } catch (_) {}
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Convenience wrapper (called by add_health_record_screen.dart)
  // ---------------------------------------------------------------------------

  /// Updates visit stats then checks whether a new alert is needed.
  /// Called after every successful save/update of a health record.
  Future<void> evaluateForUser(String userId) async {
    await updateVisitStats(userId);
    await createCheckupAlertIfNeeded(userId);
  }
}
