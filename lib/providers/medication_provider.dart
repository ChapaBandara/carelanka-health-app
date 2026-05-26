import 'package:flutter/material.dart';

class MedicationProvider extends ChangeNotifier {
  bool isLoading = false;

  void setLoading(bool value) {
    isLoading = value;
    notifyListeners();
  }
}
