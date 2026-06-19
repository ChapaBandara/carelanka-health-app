import 'package:carelanka_app/providers/family_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

extension ActiveUidContext on BuildContext {
  /// Use this everywhere instead of
  /// FirebaseAuth.instance.currentUser!.uid
  /// It automatically returns the switched account's UID when active.
  String get activeUid {
    final own = FirebaseAuth.instance.currentUser?.uid ?? '';
    try {
      final family = read<FamilyProvider>();
      return family.activeUid(own);
    } catch (_) {
      return own;
    }
  }
}
