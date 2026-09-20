import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carelanka_app/services/adherence_service.dart';
import 'package:carelanka_app/core/firebase/firebase_collections.dart';

void main() {
  group('UT-03: Adherence Score Calculation', () {
    test('14 total / 10 confirmed / 4 missed => 71.4%, no shift', () async {
      final fakeFirestore = FakeFirebaseFirestore();
      const userId = 'testUser';
      const medId = 'testMed';
      final now = DateTime.now();

      for (var i = 0; i < 10; i++) {
        await fakeFirestore.collection(FirebaseCollections.reminderLogs).add({
          'userId': userId,
          'medicationId': medId,
          'status': 'confirmed',
          'scheduledTime': Timestamp.fromDate(now.subtract(Duration(hours: i))),
        });
      }
      for (var i = 0; i < 4; i++) {
        await fakeFirestore.collection(FirebaseCollections.reminderLogs).add({
          'userId': userId,
          'medicationId': medId,
          'status': 'missed',
          'scheduledTime': Timestamp.fromDate(now.subtract(Duration(hours: i))),
        });
      }

      final service = AdherenceService(firestore: fakeFirestore);
      final score = await service.calculate7DayScore(userId, medId);

      // ignore: avoid_print
      print('calculate7DayScore(14 total, 10 confirmed) => ${score.toStringAsFixed(1)}%   '
          '(expected 71.4%)   ${(score - 71.4).abs() < 0.1 ? "PASS" : "FAIL"}');
      expect(score, closeTo(71.4, 0.1));
    });

    test('14 total / 8 confirmed / 6 missed => 57.1%, shift', () async {
      final fakeFirestore = FakeFirebaseFirestore();
      const userId = 'testUser';
      const medId = 'testMed';
      final now = DateTime.now();

      for (var i = 0; i < 8; i++) {
        await fakeFirestore.collection(FirebaseCollections.reminderLogs).add({
          'userId': userId,
          'medicationId': medId,
          'status': 'confirmed',
          'scheduledTime': Timestamp.fromDate(now.subtract(Duration(hours: i))),
        });
      }
      for (var i = 0; i < 6; i++) {
        await fakeFirestore.collection(FirebaseCollections.reminderLogs).add({
          'userId': userId,
          'medicationId': medId,
          'status': 'missed',
          'scheduledTime': Timestamp.fromDate(now.subtract(Duration(hours: i))),
        });
      }

      final service = AdherenceService(firestore: fakeFirestore);
      final score = await service.calculate7DayScore(userId, medId);

      // ignore: avoid_print
      print('calculate7DayScore(14 total, 8 confirmed) => ${score.toStringAsFixed(1)}%   '
          '(expected 57.1%)   ${(score - 57.1).abs() < 0.1 ? "PASS" : "FAIL"}');
      expect(score, closeTo(57.1, 0.1));
    });
  });

  group('UT-04: Stock-Level Days-Remaining Calculation', () {
       test('all 5 rows from the appendix', () {
      final service = AdherenceService(firestore: FakeFirebaseFirestore());
      final cases = [
        [14, 2, 7, true],
        [16, 2, 7, false],
        [7, 1, 7, true],
        [21, 3, 7, true],
        [30, 3, 7, false],
      ];
      for (final c in cases) {
        final stock = c[0] as int;
        final freq = c[1] as int;
        final threshold = c[2] as int;
        final expectedAlert = c[3] as bool;

        final days = service.calculateStockDaysRemaining(stock, freq);
        final fires = service.isStockLow(stock, freq, threshold);

        // ignore: avoid_print
        print('$stock/$freq/$threshold => ${days}d => alert=$fires   '
            '(expected alert=$expectedAlert)   ${fires == expectedAlert ? "PASS" : "FAIL"}');
        expect(fires, expectedAlert);
      }
    });
  });
}