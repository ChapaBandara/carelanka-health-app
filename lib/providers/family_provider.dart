import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Manages the active profile context — supports Instagram-style switching
/// between the main account, linked family accounts, and dependent profiles.
class FamilyProvider extends ChangeNotifier {
  Map<String, String>? _activeMember;
  String? _ownerUid;

  Map<String, String>? get activeMember => _activeMember;

  bool get isViewingFamilyMember => _activeMember != null;

  String get activeDisplayName => _activeMember?['name'] ?? 'My Account';

  /// The profileId of the currently active family member (null = self).
  String? get activeFamilyProfileId => _activeMember?['profileId'];

  /// Returns true when viewing a dependent (not a linked account).
  bool get isViewingDependent =>
      _activeMember != null && _activeMember!['type'] == 'dependent';

  /// Returns the UID to use for ALL Firestore queries across the app.
  ///
  /// - For linked accounts → returns their `linkedUserId`
  /// - For own account → returns own UID
  /// - For dependents → returns own UID (dependents are stored under owner)
  String activeUid(String ownUid) {
    if (_activeMember == null) return ownUid;
    final linkedUid = _activeMember!['linkedUserId'] ?? '';
    if (linkedUid.isNotEmpty && _activeMember!['type'] != 'dependent') {
      return linkedUid;
    }
    // Dependents use the owner's UID — their data is partitioned by scopeId
    return ownUid;
  }

  /// Returns the scope identifier for Firestore queries.
  ///
  /// This is the KEY distinction for dependent support:
  /// - Own account → `ownUid`
  /// - Linked account → their `linkedUserId`
  /// - Dependent profile → `profileId` (data stored with scopeId = profileId)
  String activeScopeId(String ownUid) {
    if (_activeMember == null) return ownUid;
    final type = _activeMember!['type'] ?? '';
    if (type == 'dependent') {
      // Dependent data is scoped to their profileId
      return _activeMember!['profileId'] ?? ownUid;
    }
    final linkedUid = _activeMember!['linkedUserId'] ?? '';
    return linkedUid.isNotEmpty ? linkedUid : ownUid;
  }

  void switchToMember(Map<String, String> member) {
    _ownerUid ??= FirebaseAuth.instance.currentUser?.uid;
    _activeMember = member;
    notifyListeners();
  }

  void switchToSelf() {
    _activeMember = null;
    notifyListeners();
  }
}
