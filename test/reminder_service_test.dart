// test/reminder_service_test.dart
//
// Evidence-capture harness for Appendix F, UT-01 and UT-02.
// Run with:  flutter test test/reminder_service_test.dart
// Screenshot the terminal output — that IS your evidence, paste it under
// the Evidence row for UT-01/UT-02 in Appendix F.
//
// This also directly demonstrates Bug #12 for the report: the AM/PM cases
// print a WARNING because they don't behave the way a 12-hour string should.

import 'package:flutter_test/flutter_test.dart';
import 'package:carelanka_app/services/reminder_service.dart';
import 'package:carelanka_app/core/utils/medication_schedule_helper.dart';

void main() {
  group('UT-01: Adaptive Time Adjustment Calculation', () {
    test('24-hour format inputs (expected PASS)', () {
      final cases = [
        ['08:40', 42.0, '07:58'],
        ['00:10', 30.0, '23:40'],
        ['12:00', 60.0, '11:00'],
        ['08:00', 0.0, '08:00'],
      ];
      for (final c in cases) {
        final input = c[0] as String;
        final delay = c[1] as double;
        final expected = c[2] as String;
        final actual = ReminderService.adjustTime(input, delay);
        // ignore: avoid_print
        print('adjustTime("$input", $delay) => $actual   (expected $expected)   '
            '${actual == expected ? "PASS" : "FAIL"}');
        expect(actual, expected);
      }
    });

    test('Bug #12 — AM/PM strings are NOT correctly handled (documented open defect)', () {
      // These calls demonstrate the real defect: int.tryParse fails on "10 AM"
      // etc., silently zeroing the minutes, and PM is never converted to 24h.
      final probes = [
        ['9:10 AM', 5.0],
        ['9:10 PM', 5.0],
        ['9:00 PM', 9.0],
      ];
      for (final p in probes) {
        final input = p[0] as String;
        final delay = p[1] as double;
        final actual = ReminderService.adjustTime(input, delay);
        // ignore: avoid_print
        print('adjustTime("$input", $delay) => $actual   '
            '<-- compare against Firestore scheduledTimes for the real pilot participant');
      }
      // No expect() here deliberately — this test documents current
      // (defective) behaviour for the report, it does not assert correctness.
    });
  });

  group('UT-02: Medication Time String Parsing', () {
    test('parseTimeOnDay formats (expected PASS after fix)', () {
      final day = DateTime(2026, 8, 28);
      final cases = [
        ['08:40 AM', 8, 40],
        ['11:00 PM', 23, 0],
        ['12:00 AM', 0, 0],
        ['12:00 PM', 12, 0],
        ['07:58', 7, 58],
      ];
      for (final c in cases) {
        final input = c[0] as String;
        final expH = c[1] as int;
        final expM = c[2] as int;
        final dt = MedicationScheduleHelper.parseTimeOnDay(input, day);
        // ignore: avoid_print
        print('parseTimeOnDay("$input") => ${dt?.hour}:${dt?.minute}   '
            '(expected $expH:$expM)   '
            '${dt != null && dt.hour == expH && dt.minute == expM ? "PASS" : "FAIL"}');
        expect(dt?.hour, expH);
        expect(dt?.minute, expM);
      }
    });
  });
}