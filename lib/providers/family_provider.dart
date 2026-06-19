import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class FamilyProvider extends ChangeNotifier {
  Map<String, String>? _activeMember;
  String? _ownerUid;

  Map<String, String>? get activeMember => _activeMember;

  bool get isViewingFamilyMember => _activeMember != null;

  String get activeDisplayName => _activeMember?['name'] ?? 'My Account';

  String? get activeProfileId => _activeMember?['profileId'];

  /// Returns the UID to use for ALL Firestore queries across the app.
  /// When viewing a family member, returns their linkedUserId.
  /// Otherwise returns the logged-in user's own UID.
  String activeUid(String ownUid) {
    if (_activeMember == null) return ownUid;
    final linkedUid = _activeMember!['linkedUserId'] ?? '';
    if (linkedUid.isNotEmpty) return linkedUid;
    // Dependent profile — no separate account, use owner's UID
    // but filter by profileId in future
    return ownUid;
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
