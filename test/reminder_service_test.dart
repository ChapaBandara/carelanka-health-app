import 'package:flutter_test/flutter_test.dart';
import 'package:carelanka_app/services/reminder_service.dart';

void main() {
  group('UT-01: Adaptive Time Adjustment Calculation', () {
    test('shifts time earlier by delay, no wrap', () {
      expect(ReminderService.adjustTime('08:40', 42.0), '07:58');
    });
    test('shifts time earlier, midnight wraparound', () {
      expect(ReminderService.adjustTime('00:10', 30.0), '23:40');
    });
    test('shifts a full hour earlier', () {
      expect(ReminderService.adjustTime('12:00', 60.0), '11:00');
    });
    test('zero delay makes no change', () {
      expect(ReminderService.adjustTime('08:00', 0.0), '08:00');
    });
  });
}