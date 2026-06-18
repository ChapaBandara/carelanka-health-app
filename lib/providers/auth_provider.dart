import 'package:carelanka_app/models/user_profile.dart';
import 'package:carelanka_app/services/auth_service.dart';
import 'package:carelanka_app/services/user_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();

  bool isLoading = false;
  bool isLoggedIn = false;
  bool hasBootstrapped = false;
  UserProfile? profile;

  /// Set after account deletion so welcome shows without auth redirects/errors.
  bool justDeletedAccount = false;

  void clearJustDeletedAccount() {
    if (!justDeletedAccount) return;
    justDeletedAccount = false;
    notifyListeners();
  }

  Future<void> bootstrap() async {
    if (isLoading) return;
    isLoading = true;

    if (justDeletedAccount) {
      isLoggedIn = false;
      profile = null;
      hasBootstrapped = true;
      isLoading = false;
      notifyListeners();
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      isLoggedIn = true;
      profile = await _userService.getUserProfile(user.uid);
    } else {
      isLoggedIn = false;
      profile = null;
    }
    hasBootstrapped = true;
    isLoading = false;
    notifyListeners();
  }

  Future<void> loadFromFirebase() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      isLoggedIn = false;
      profile = null;
    } else {
      isLoggedIn = true;
      profile = await _userService.getUserProfile(user.uid);
    }
    notifyListeners();
  }

  Future<void> signIn({
    required String fullName,
    required String email,
    required String phone,
    DateTime? dateOfBirth,
    String? gender,
    String? bloodType,
    String? emergencyContactName,
    String? emergencyContactPhone,
    bool isDependent = false,
    String? guardianName,
    String? password,
  }) async {
    if (password == null || password.isEmpty) {
      throw Exception('Password is required');
    }

    final credential = await _authService.createUserWithEmailAndPassword(email, password);
    final uid = credential.user!.uid;

    await _userService.createUserDocument(
      uid: uid,
      fullName: fullName,
      email: email,
      phone: phone,
      dateOfBirth: dateOfBirth,
      gender: gender,
      bloodType: bloodType,
      emergencyContactName: emergencyContactName,
      emergencyContactPhone: emergencyContactPhone,
    );

    if (isDependent) {
      await _userService.updateUser(uid, {
        'isDependent': true,
        if (guardianName != null) 'guardianName': guardianName,
      });
    }

    await loadFromFirebase();
  }

  Future<bool> loginWithCredentials(String emailOrPhone, String password) async {
    try {
      final email = await _authService.resolveEmailForLogin(emailOrPhone);
      await _authService.signInWithEmailAndPassword(email, password);
      await loadFromFirebase();
      return isLoggedIn;
    } catch (_) {
      return false;
    }
  }

  Future<void> updateProfile(UserProfile updated) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await _userService.updateUser(uid, {
      'fullName': updated.fullName,
      'email': updated.email,
      'phone': updated.phone.replaceAll(RegExp(r'\D'), ''),
      if (updated.dateOfBirth != null) 'dateOfBirth': Timestamp.fromDate(updated.dateOfBirth!),
      if (updated.gender != null) 'gender': updated.gender,
      if (updated.bloodType != null) 'bloodType': updated.bloodType,
      if (updated.profileImageUrl != null) 'profileImageUrl': updated.profileImageUrl,
      if (updated.emergencyContactName != null) 'emergencyContactName': updated.emergencyContactName,
      if (updated.emergencyContactPhone != null) 'emergencyContactPhone': updated.emergencyContactPhone,
    });
    profile = updated;
    notifyListeners();
  }

  Future<void> signOut() async {
    await _authService.signOut();
    profile = null;
    isLoggedIn = false;
    notifyListeners();
  }

  Future<void> reauthenticateWithPassword({required String email, required String password}) async {
    await _authService.reauthenticateWithPassword(email, password);
  }

  Future<void> deleteAccount({required String password}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('You must be signed in to delete your account.');
    }
    final email = user.email ?? profile?.email;
    if (email == null || email.isEmpty) {
      throw Exception('Account email not found.');
    }

    await _authService.reauthenticateWithPassword(email, password);

    try {
      await _userService.deleteUserData(user.uid);
    } catch (_) {}

    try {
      await _authService.deleteAuthUser();
    } on FirebaseAuthException catch (e) {
      if (e.code != 'user-not-found') rethrow;
    }

    try {
      await _authService.signOut();
    } catch (_) {}

    profile = null;
    isLoggedIn = false;
    justDeletedAccount = true;
    notifyListeners();
  }
}
