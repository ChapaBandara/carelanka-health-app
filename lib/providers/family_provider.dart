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
    // If no linked account, this is a dependent profile.
    // For dependents, we cannot show their separate data
    // because they share the owner's Firestore data.
    if (linkedUid.isEmpty) {
      return ownUid; // dependent uses owner's data
    }
    return linkedUid;
  }

  void switchToMember(Map<String, String> member) {
    _ownerUid ??= FirebaseAuth.instance.currentUser?.uid;
    _activeMember = member;

    // Debug: print what UID will be used
    final linkedUid = member['linkedUserId'] ?? '';
    final hasLinkedAccount = member['hasOwnAccount'] == 'true' &&
        linkedUid.isNotEmpty;

    if (!hasLinkedAccount) {
      // This is a dependent profile — data will use owner's UID
      // which means we see the owner's data for dependents
      // This is expected behavior for dependents without their own account
    }

    notifyListeners();
  }

  void switchToSelf() {
    _activeMember = null;
    notifyListeners();
  }
}
