import 'dart:convert';

import 'package:carelanka_app/models/user_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local session persistence (no Firebase). Replace with Firebase Auth when backend is ready.
class SessionService {
  static const _keyLoggedIn = 'session_logged_in';
  static const _keyProfile = 'session_profile';
  static const _keyPassword = 'session_password';

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyLoggedIn) ?? false;
  }

  Future<UserProfile?> loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyProfile);
    if (raw == null) return null;
    return UserProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> saveSession(UserProfile profile, {String? password}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyLoggedIn, true);
    await prefs.setString(_keyProfile, jsonEncode(profile.toJson()));
    if (password != null) {
      await prefs.setString(_keyPassword, password);
    }
  }

  Future<String?> loadPassword() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPassword);
  }

  Future<bool> validateLogin(String emailOrPhone, String password) async {
    final profile = await loadProfile();
    final stored = await loadPassword();
    if (profile == null || stored == null) return false;
    final input = emailOrPhone.trim().toLowerCase();
    final emailMatch = profile.email.toLowerCase() == input;
    final phoneDigits = emailOrPhone.replaceAll(RegExp(r'\D'), '');
    final profileDigits = profile.phone.replaceAll(RegExp(r'\D'), '');
    final phoneMatch = phoneDigits.isNotEmpty && profileDigits.endsWith(phoneDigits);
    return (emailMatch || phoneMatch) && stored == password;
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyLoggedIn);
    await prefs.remove(_keyProfile);
    await prefs.remove(_keyPassword);
  }
}
