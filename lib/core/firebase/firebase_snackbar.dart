import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

void showFirebaseSuccessSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: Colors.green.shade700,
      behavior: SnackBarBehavior.floating,
    ),
  );
}

void showFirebaseErrorSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: Colors.red.shade700,
      behavior: SnackBarBehavior.floating,
    ),
  );
}

String firebaseErrorMessage(Object error) {
  if (error is FirebaseFunctionsException) {
    if (error.code == 'not-found' || error.code == 'unavailable') {
      return 'Password reset service is not available yet. Deploy Cloud Functions '
          '(Firebase Blaze plan required), then try again.';
    }
    return error.message ?? error.code;
  }
  if (error is FirebaseAuthException) {
    final message = error.message ?? '';
    if (error.code == 'unknown' && message.contains('CONFIGURATION_NOT_FOUND')) {
      return 'Firebase Authentication is not set up yet. In Firebase Console, open '
          'Authentication → Sign-in method, enable Email/Password, save, then fully '
          'restart the app (stop and run again, not hot reload).';
    }
    switch (error.code) {
      case 'user-not-found':
        return 'No account found. Register first to create your CareLanka account.';
      case 'wrong-password':
        return 'Incorrect password. Try again or use Forgot Password.';
      case 'invalid-credential':
      case 'invalid-login-credentials':
        return 'No account found or wrong password. Register if you have not signed up yet.';
      case 'email-already-in-use':
        return 'This email is already registered. Try logging in instead.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'network-request-failed':
        return 'Network error. Check your internet connection and try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait and try again.';
      case 'requires-recent-login':
        return 'For security, enter your password again to delete your account.';
      default:
        return error.message ?? error.code;
    }
  }
  if (error is Exception) {
    return error.toString().replaceFirst('Exception: ', '');
  }
  final text = error.toString();
  if (text.contains('CONFIGURATION_NOT_FOUND')) {
    return 'Firebase Authentication is not set up yet. Enable Email/Password in '
        'Firebase Console → Authentication → Sign-in method, then restart the app.';
  }
  return text;
}
