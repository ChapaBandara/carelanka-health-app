import 'package:carelanka_app/widgets/carelanka/success_notification_overlay.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Title + subtitle for CareLanka auth overlays.
class AuthNotificationCopy {
  const AuthNotificationCopy({required this.title, required this.subtitle});

  final String title;
  final String subtitle;
}

// CareLanka UI — 04 Login Notification Screen
const _loginSuccess = AuthNotificationCopy(
  title: 'Login Successful',
  subtitle: 'Welcome back to CareLanka! Redirecting to your dashboard...',
);

// CareLanka UI — Register account notification (same banner pattern as login / medication saved)
const _registerSuccess = AuthNotificationCopy(
  title: 'Account Created Successfully',
  subtitle: 'Your CareLanka account is ready. Redirecting to your dashboard...',
);

AuthNotificationCopy authErrorCopy(Object error) {
  if (error is FirebaseAuthException) {
    final raw = error.message ?? '';
    if (error.code == 'unknown' && raw.contains('CONFIGURATION_NOT_FOUND')) {
      return const AuthNotificationCopy(
        title: 'Authentication not configured',
        subtitle:
            'Enable Email/Password in Firebase Console → Authentication → Sign-in method, '
            'then fully restart the app.',
      );
    }

    switch (error.code) {
      case 'user-not-found':
        return const AuthNotificationCopy(
          title: 'Login Failed',
          subtitle:
              'No account found with this email. Tap Register to create your CareLanka account first.',
        );
      case 'wrong-password':
        return const AuthNotificationCopy(
          title: 'Login Failed',
          subtitle: 'The password is incorrect. Try again or tap Forgot Password.',
        );
      case 'invalid-credential':
      case 'invalid-login-credentials':
        return const AuthNotificationCopy(
          title: 'Login Failed',
          subtitle:
              'No account found with these details, or the password is wrong. '
              'Register first if you have not created an account.',
        );
      case 'email-already-in-use':
        return const AuthNotificationCopy(
          title: 'Registration Failed',
          subtitle: 'This email is already registered. Go to Login to sign in.',
        );
      case 'weak-password':
        return const AuthNotificationCopy(
          title: 'Registration Failed',
          subtitle: 'Password is too weak. Use at least 6 characters.',
        );
      case 'invalid-email':
        return const AuthNotificationCopy(
          title: 'Registration Failed',
          subtitle: 'Please enter a valid email address.',
        );
      case 'operation-not-allowed':
        return const AuthNotificationCopy(
          title: 'Registration Failed',
          subtitle: 'Email sign-up is not enabled. Contact support.',
        );
      case 'too-many-requests':
        return const AuthNotificationCopy(
          title: 'Login Failed',
          subtitle: 'Too many attempts. Please wait a few minutes and try again.',
        );
      case 'user-disabled':
        return const AuthNotificationCopy(
          title: 'Login Failed',
          subtitle: 'This account has been disabled. Contact support for help.',
        );
      case 'network-request-failed':
        return const AuthNotificationCopy(
          title: 'Connection problem',
          subtitle: 'Check your internet connection and try again.',
        );
      default:
        return AuthNotificationCopy(
          title: 'Something went wrong',
          subtitle: error.message ?? 'Please try again.',
        );
    }
  }

  final text = error.toString().replaceFirst('Exception: ', '');
  final lower = text.toLowerCase();

  if (lower.contains('no account found') && lower.contains('phone')) {
    return const AuthNotificationCopy(
      title: 'Login Failed',
      subtitle:
          'This phone number is not registered. Tap Register to create an account, or sign in with email.',
    );
  }
  if (lower.contains('no account found')) {
    return const AuthNotificationCopy(
      title: 'Login Failed',
      subtitle: 'No account found. Tap Register to create your CareLanka account first.',
    );
  }
  if (text.contains('CONFIGURATION_NOT_FOUND')) {
    return const AuthNotificationCopy(
      title: 'Authentication not configured',
      subtitle:
          'Enable Email/Password in Firebase Console → Authentication → Sign-in method, '
          'then fully restart the app.',
    );
  }

  return AuthNotificationCopy(
    title: 'Something went wrong',
    subtitle: text.isEmpty ? 'Please try again.' : text,
  );
}

/// How long login/register success banners stay fully visible (2–3 seconds).
const authSuccessNotificationDuration = Duration(milliseconds: 2500);

/// CareLanka UI — Login Notification Screen (success).
Future<void> showLoginSuccessNotification(BuildContext context) {
  return showCareLankaSuccessNotification(
    context,
    title: _loginSuccess.title,
    subtitle: _loginSuccess.subtitle,
    displayFor: authSuccessNotificationDuration,
    belowAppBar: true,
  );
}

/// CareLanka UI — Register account notification (success).
const _codeSentSuccess = AuthNotificationCopy(
  title: 'Code Sent',
  subtitle: 'Code sent to your email',
);

/// CareLanka overlay after forgot-password OTP email is sent.
Future<void> showCodeSentToEmailNotification(BuildContext context) {
  return showCareLankaSuccessNotification(
    context,
    title: _codeSentSuccess.title,
    subtitle: _codeSentSuccess.subtitle,
    displayFor: authSuccessNotificationDuration,
    belowAppBar: true,
  );
}

const _passwordResetLinkSent = AuthNotificationCopy(
  title: 'Identity Verified',
  subtitle:
      'Your identity is verified. We have sent a password reset link to your email. '
      'Please check your email and click the link to set your new password.',
);

/// CareLanka overlay after email OTP is verified and Firebase reset link is sent.
Future<void> showPasswordResetLinkSentNotification(BuildContext context) {
  return showCareLankaSuccessNotification(
    context,
    title: _passwordResetLinkSent.title,
    subtitle: _passwordResetLinkSent.subtitle,
    displayFor: authSuccessNotificationDuration,
    belowAppBar: true,
  );
}

Future<void> showRegisterSuccessNotification(BuildContext context) {
  return showCareLankaSuccessNotification(
    context,
    title: _registerSuccess.title,
    subtitle: _registerSuccess.subtitle,
    displayFor: authSuccessNotificationDuration,
    belowAppBar: true,
  );
}

Future<void> showLoginErrorNotification(BuildContext context, Object error) {
  final copy = authErrorCopy(error);
  return showCareLankaErrorNotification(
    context,
    title: copy.title,
    subtitle: copy.subtitle,
  );
}

const _accountDeletedSuccess = AuthNotificationCopy(
  title: 'Account Deleted',
  subtitle: 'Your CareLanka account has been removed. We hope to see you again.',
);

/// CareLanka overlay after account deletion (same pattern as login success).
Future<void> showAccountDeletedNotification(BuildContext context) {
  return showCareLankaSuccessNotification(
    context,
    title: _accountDeletedSuccess.title,
    subtitle: _accountDeletedSuccess.subtitle,
    displayFor: authSuccessNotificationDuration,
  );
}

Future<void> showRegisterErrorNotification(BuildContext context, Object error) {
  final copy = authErrorCopy(error);
  final title = copy.title == 'Login Failed' ? 'Registration Failed' : copy.title;
  return showCareLankaErrorNotification(
    context,
    title: title,
    subtitle: copy.subtitle,
  );
}
