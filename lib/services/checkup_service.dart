import 'package:carelanka_app/core/firebase/firebase_collections.dart';
import 'package:carelanka_app/services/alert_service.dart';
import 'package:carelanka_app/services/notification_service.dart';
import 'package:carelanka_app/services/user_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CheckupService {
  CheckupService({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const int gapDays = 180;

  Future<DateTime?> lastCheckupDate(String userId) async {
    DateTime? latest;

    final records = await _firestore
        .collection(FirebaseCollections.healthRecords)
        .where('userId', isEqualTo: userId)
        .get();
    for (final doc in records.docs) {
      final visit = doc.data()['visitDate'];
      if (visit is Timestamp) {
        final d = visit.toDate();
        if (latest == null || d.isAfter(latest)) latest = d;
      }
    }

    final now = DateTime.now();
    final appointments = await _firestore
        .collection(FirebaseCollections.appointments)
        .where('userId', isEqualTo: userId)
        .get();
    for (final doc in appointments.docs) {
      final dtField = doc.data()['dateTime'];
      if (dtField is Timestamp) {
        final d = dtField.toDate();
        if (d.isBefore(now) && (latest == null || d.isAfter(latest))) {
          latest = d;
        }
      }
    }

    return latest;
  }

  Future<int?> daysSinceLastCheckup(String userId) async {
    final last = await lastCheckupDate(userId);
    if (last == null) return null;
    return DateTime.now().difference(last).inDays;
  }

  Future<bool> isCheckupOverdue(String userId) async {
    final days = await daysSinceLastCheckup(userId);
    if (days == null) return false;
    return days >= gapDays;
  }

  Future<void> evaluateForUser(String userId) async {
    final prefs = await UserService().getNotificationPreferences(userId);
    if (prefs?['checkupSuggestions'] == false) return;

    final days = await daysSinceLastCheckup(userId);
    if (days == null || days < gapDays) {
      if (days != null && days < gapDays) {
        await AlertService().dismissUnreadCheckupAlerts(userId);
      }
      return;
    }

    if (await AlertService().hasUnreadCheckupAlert(userId)) return;

    await AlertService().createCheckupAlert(userId: userId, daysSinceCheckup: days);
    await NotificationService.instance.showCheckupSuggestion(daysSinceCheckup: days);
  }
}
