import 'package:carelanka_app/providers/family_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

extension ActiveUidContext on BuildContext {
  /// Returns the UID for Firestore user-level queries.
  ///
  /// - For linked accounts: returns their linked UID
  /// - For dependents and self: returns own UID
  ///
  /// Use [activeScopeId] instead when querying health data collections
  /// (medications, illnesses, appointments, records, reminders, allergies).
  String get activeUid {
    final own = FirebaseAuth.instance.currentUser?.uid ?? '';
    try {
      final family = read<FamilyProvider>();
      return family.activeUid(own);
    } catch (_) {
      return own;
    }
  }

  /// Returns the scope ID for ALL health data Firestore queries.
  ///
  /// This is the key for dependent profile data partitioning:
  /// - Own account → own UID
  /// - Linked account → their linked UID
  /// - Dependent profile → their profileId (data stored with scopeId = profileId)
  String get activeScopeId {
    final own = FirebaseAuth.instance.currentUser?.uid ?? '';
    try {
      final family = read<FamilyProvider>();
      return family.activeScopeId(own);
    } catch (_) {
      return own;
    }
  }
}
