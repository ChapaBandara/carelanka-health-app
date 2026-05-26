import 'package:flutter/material.dart';

/// In-memory health data for Phase 1 UI. Starts empty for new accounts.
/// No Firebase/database — data is not persisted across app restarts yet.
class UserDataProvider extends ChangeNotifier {
  final List<Map<String, String>> medications = [];
  final List<Map<String, String>> illnesses = [];
  final List<Map<String, String>> records = [];
  final List<Map<String, String>> appointments = [];
  final List<Map<String, String>> allergies = [];
  final List<Map<String, String>> familyMembers = [];
  final List<Map<String, String>> reminders = [];
  final List<Map<String, String>> alerts = [];

  bool get hasMedications => medications.isNotEmpty;
  bool get hasIllnesses => illnesses.isNotEmpty;
  bool get hasRecords => records.isNotEmpty;
  bool get hasAppointments => appointments.isNotEmpty;
  bool get hasAllergies => allergies.isNotEmpty;
  bool get hasFamily => familyMembers.isNotEmpty;
  bool get hasReminders => reminders.isNotEmpty;
  bool get hasAlerts => alerts.isNotEmpty;

  /// Owner account: all sections start empty.
  void resetForOwner() {
    medications.clear();
    illnesses.clear();
    records.clear();
    appointments.clear();
    allergies.clear();
    familyMembers.clear();
    reminders.clear();
    alerts.clear();
    notifyListeners();
  }

  void addFamilyMember(Map<String, String> member) {
    familyMembers.add(member);
    notifyListeners();
  }

  void addIllness(Map<String, String> illness) {
    illnesses.add(illness);
    notifyListeners();
  }

  void addMedication(Map<String, String> medication) {
    medications.add(medication);
    notifyListeners();
  }

  void addAppointment(Map<String, String> appointment) {
    appointments.add(appointment);
    notifyListeners();
  }

  void addRecord(Map<String, String> record) {
    records.add(record);
    notifyListeners();
  }

  void addAllergy(Map<String, String> allergy) {
    allergies.add(allergy);
    notifyListeners();
  }

  void addReminder(Map<String, String> reminder) {
    reminders.add(reminder);
    notifyListeners();
  }

  void addAlert(Map<String, String> alert) {
    alerts.add(alert);
    notifyListeners();
  }

  /// Dependent account: only family link visible.
  void resetForDependent({required String guardianName, required String dependentName}) {
    resetForOwner();
    familyMembers.add({
      'name': guardianName,
      'meta': 'Primary account • Linked',
      'initials': _initials(guardianName),
      'type': 'guardian',
    });
    notifyListeners();
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}
