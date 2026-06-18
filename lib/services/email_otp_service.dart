import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';

/// In-memory email OTP for forgot-password (sent via EmailJS).
class EmailOtpService {
  EmailOtpService({
    FirebaseAuth? auth,
  }) : _auth = auth ?? FirebaseAuth.instance;

  static const otpExpiry = Duration(minutes: 10);

  static final EmailOtpService instance = EmailOtpService();

  final FirebaseAuth _auth;

  _EmailOtpSession? _session;

  Duration? get remainingOtpTime {
    final session = _session;
    if (session == null) return null;
    final remaining = otpExpiry - DateTime.now().difference(session.sentAt);
    if (remaining.isNegative) return Duration.zero;
    return remaining;
  }

  String _generateOtp() => (Random().nextInt(900000) + 100000).toString();

  /// Generates OTP, stores in memory, returns code for EmailJS send.
  Future<String> prepareOtp(String email) async {
    final trimmed = email.trim();
    if (trimmed.isEmpty) {
      throw Exception('Please enter your email address.');
    }

    final otp = _generateOtp();
    _session = _EmailOtpSession(
      email: trimmed,
      otp: otp,
      sentAt: DateTime.now(),
      verified: false,
    );

    return otp;
  }

  /// Verifies the in-memory OTP without sending email.
  Future<void> verifyOtpCode({required String email, required String code}) async {
    final trimmed = email.trim();
    final session = _session;

    if (session == null || session.email != trimmed) {
      throw const OtpExpiredException();
    }

    if (DateTime.now().difference(session.sentAt) > otpExpiry) {
      throw const OtpExpiredException();
    }

    if (session.otp != code.trim()) {
      throw const OtpIncorrectException();
    }

    session.verified = true;
  }

  /// Verifies the in-memory OTP, then sends a Firebase password reset email.
  Future<void> verifyOtp({required String email, required String code}) async {
    await verifyOtpCode(email: email, code: code);
    await completePasswordReset(email: email);
  }

  Future<void> completePasswordReset({required String email}) async {
    final trimmed = email.trim();
    await _auth.sendPasswordResetEmail(email: trimmed);
    _session = null;
  }

  void clearSession() => _session = null;
}

class _EmailOtpSession {
  _EmailOtpSession({
    required this.email,
    required this.otp,
    required this.sentAt,
    required this.verified,
  });

  final String email;
  final String otp;
  final DateTime sentAt;
  bool verified;
}

class OtpIncorrectException implements Exception {
  const OtpIncorrectException();
}

class OtpExpiredException implements Exception {
  const OtpExpiredException();
}
