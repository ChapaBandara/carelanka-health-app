import 'package:flutter_test/flutter_test.dart';
import 'package:carelanka_app/services/drug_interaction_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UT-05: Drug Conflict Message Deduplication', () {
    test('same-drug conflict (Warfarin) produces ONE message, not duplicated', () async {
      const service = DrugInteractionService();

      final result = await service.checkAll(
        'Aspirin',
        'testUser',
        existingMedications: [
          {'name': 'Warfarin'},
        ],
      );

      final messageLines = (result.conflictMessage ?? '')
          .split('\n')
          .where((l) => l.trim().isNotEmpty)
          .toList();

      // ignore: avoid_print
      print('Same-drug case (Aspirin vs existing Warfarin):');
      // ignore: avoid_print
      print('  conflictingMedicationNames => ${result.conflictingMedicationNames}');
      // ignore: avoid_print
      print('  message lines => $messageLines');
      // ignore: avoid_print
      print('  ${result.conflictingMedicationNames.length == 1 && messageLines.length == 1 ? "PASS" : "FAIL"}'
          '  (expected exactly 1 conflicting drug, 1 message line)');

      expect(result.conflictingMedicationNames.length, 1);
      expect(messageLines.length, 1);
    });

    test('two different conflicting drugs produce TWO separate messages', () async {
      const service = DrugInteractionService();

      final result = await service.checkAll(
        'Warfarin',
        'testUser',
        existingMedications: [
          {'name': 'Aspirin'},
          {'name': 'Ibuprofen'},
        ],
      );

      final messageLines = (result.conflictMessage ?? '')
          .split('\n')
          .where((l) => l.trim().isNotEmpty)
          .toList();

      // ignore: avoid_print
      print('Two-different-drugs case (Warfarin vs existing Aspirin + Ibuprofen):');
      // ignore: avoid_print
      print('  conflictingMedicationNames => ${result.conflictingMedicationNames}');
      // ignore: avoid_print
      print('  message lines => $messageLines');
      // ignore: avoid_print
      print('  ${result.conflictingMedicationNames.length == 2 && messageLines.length == 2 ? "PASS" : "FAIL"}'
          '  (expected exactly 2 conflicting drugs, 2 message lines)');

      expect(result.conflictingMedicationNames.length, 2);
      expect(messageLines.length, 2);
    });
  });
}