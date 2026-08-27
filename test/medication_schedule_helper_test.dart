import 'package:flutter_test/flutter_test.dart';
import 'package:carelanka_app/core/utils/medication_schedule_helper.dart';

void main() {
  final testDay = DateTime(2026, 1, 15); // any fixed date works, just needs to be consistent

  group('UT-02: Medication Time String Parsing', () {
    test('parses 12-hour AM time', () {
      final result = MedicationScheduleHelper.parseTimeOnDay('08:40 AM', testDay);
      expect(result?.hour, 8);
      expect(result?.minute, 40);
    });
    test('parses 12-hour PM time', () {
      final result = MedicationScheduleHelper.parseTimeOnDay('11:00 PM', testDay);
      expect(result?.hour, 23);
      expect(result?.minute, 0);
    });
    test('parses midnight correctly', () {
      final result = MedicationScheduleHelper.parseTimeOnDay('12:00 AM', testDay);
      expect(result?.hour, 0);
      expect(result?.minute, 0);
    });
    test('parses noon correctly', () {
      final result = MedicationScheduleHelper.parseTimeOnDay('12:00 PM', testDay);
      expect(result?.hour, 12);
      expect(result?.minute, 0);
    });
    test('parses 24-hour string from algorithm output', () {
      final result = MedicationScheduleHelper.parseTimeOnDay('07:58', testDay);
      expect(result?.hour, 7);
      expect(result?.minute, 58);
    });
  });
}