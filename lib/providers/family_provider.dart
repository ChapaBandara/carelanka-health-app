import 'package:flutter/foundation.dart';

class FamilyProvider extends ChangeNotifier {
  Map<String, String>? _activeMember;

  Map<String, String>? get activeMember => _activeMember;

  bool get isViewingFamilyMember => _activeMember != null;

  String get activeDisplayName => _activeMember?['name'] ?? 'My account';

  String? get activeProfileId => _activeMember?['profileId'];

  String? get activeLinkedUserId => _activeMember?['linkedUserId'];

  void switchToMember(Map<String, String> member) {
    _activeMember = Map<String, String>.from(member);
    notifyListeners();
  }

  void switchToSelf() {
    _activeMember = null;
    notifyListeners();
  }
}
