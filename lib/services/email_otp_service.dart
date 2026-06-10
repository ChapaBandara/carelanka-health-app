import 'dart:math';

import 'package:carelanka_app/core/firebase/firebase_collections.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

/// In-memory email OTP for forgot-password (sent via EmailJS).
class EmailOtpService {
  EmailOtpService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instance;

  static const _otpExpiry = Duration(minutes: 10);
  static const _passwordResetExpiry = Duration(minutes: 15);

  static final EmailOtpService instance = EmailOtpService();

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  _EmailOtpSession? _session;

  String _generateOtp() => (Random().nextInt(900000) + 100000).toString();

  String _emailDocId(String email) => email.trim().toLowerCase().replaceAll('.', ',');

  Future<void> _ensureEmailAccount(String email) async {
    final trimmed = email.trim();
    final snap = await _firestore
        .collection(FirebaseCollections.users)
        .where('email', isEqualTo: trimmed)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) {
      throw Exception('No CareLanka account found with this email.');
    }
  }

  Future<void> _persistSession(_EmailOtpSession session) async {
    final verifiedAt = session.verifiedAt;
    await _firestore.collection(FirebaseCollections.passwordResetOtps).doc(_emailDocId(session.email)).set({
      'email': session.email,
      'otp': session.otp,
      'expiresAt': Timestamp.fromDate(session.sentAt.add(_otpExpiry)),
      'verified': session.verified,
      if (verifiedAt != null) 'verifiedAt': Timestamp.fromDate(verifiedAt),
      if (verifiedAt != null)
        'passwordResetExpiresAt': Timestamp.fromDate(verifiedAt.add(_passwordResetExpiry)),
    });
  }

  /// Generates OTP, stores in memory, returns code for EmailJS send.
  Future<String> prepareOtp(String email) async {
    final trimmed = email.trim();
    await _ensureEmailAccount(trimmed);

    final otp = _generateOtp();
    _session = _EmailOtpSession(
      email: trimmed,
      otp: otp,
      sentAt: DateTime.now(),
      verified: false,
    );

    await _persistSession(_session!);
    return otp;
  }

  /// Verifies the in-memory OTP for [email].
  Future<void> verifyOtp({required String email, required String code}) async {
    final trimmed = email.trim();
    final session = _session;

    if (session == null || session.email != trimmed) {
      throw const OtpExpiredException();
    }

    if (DateTime.now().difference(session.sentAt) > _otpExpiry) {
      throw const OtpExpiredException();
    }

    if (session.otp != code.trim()) {
      throw const OtpIncorrectException();
    }

    session.verified = true;
    session.verifiedAt = DateTime.now();
    await _persistSession(session);
  }

  Future<void> completePasswordReset({
    required String email,
    required String newPassword,
  }) async {
    final trimmed = email.trim();
    final session = _session;

    if (session == null || session.email != trimmed || !session.verified) {
      throw const OtpExpiredException();
    }

    final verifiedAt = session.verifiedAt;
    if (verifiedAt == null ||
        DateTime.now().difference(verifiedAt) > _passwordResetExpiry) {
      throw const OtpExpiredException();
    }

    try {
      await _functions.httpsCallable('completeEmailPasswordReset').call({
        'email': trimmed,
        'newPassword': newPassword,
      });
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'failed-precondition') {
        throw const OtpExpiredException();
      }
      rethrow;
    } finally {
      _session = null;
      await _firestore
          .collection(FirebaseCollections.passwordResetOtps)
          .doc(_emailDocId(trimmed))
          .delete()
          .catchError((_) {});
    }
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
  DateTime? verifiedAt;
}

class OtpIncorrectException implements Exception {
  const OtpIncorrectException();
}

class OtpExpiredException implements Exception {
  const OtpExpiredException();
}
