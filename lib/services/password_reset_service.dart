import 'dart:async';

import 'package:carelanka_app/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Phone-based password reset (SMS OTP via Firebase Phone Auth).
class PasswordResetService {
  PasswordResetService({
    FirebaseAuth? auth,
    AuthService? authService,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _authService = authService ?? AuthService();

  final FirebaseAuth _auth;
  final AuthService _authService;

  /// Resolves phone to account email and starts Firebase SMS verification.
  Future<PhoneOtpRequest> sendPhoneOtp(String phoneInput) async {
    final digits = phoneInput.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 9) {
      throw Exception('Enter a valid 9-digit Sri Lanka mobile number.');
    }

    final email = await _authService.resolveEmailForLogin(digits);
    final phoneE164 = '+94$digits';

    final verificationIdCompleter = Completer<String>();

    await _auth.verifyPhoneNumber(
      phoneNumber: phoneE164,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (_) {},
      verificationFailed: (FirebaseAuthException e) {
        if (!verificationIdCompleter.isCompleted) {
          verificationIdCompleter.completeError(
            Exception(e.message ?? 'Could not send SMS. Check the number and try again.'),
          );
        }
      },
      codeSent: (String verificationId, int? resendToken) {
        if (!verificationIdCompleter.isCompleted) {
          verificationIdCompleter.complete(verificationId);
        }
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        if (!verificationIdCompleter.isCompleted) {
          verificationIdCompleter.complete(verificationId);
        }
      },
    );

    final verificationId = await verificationIdCompleter.future;

    return PhoneOtpRequest(
      email: email,
      phoneE164: phoneE164,
      verificationId: verificationId,
    );
  }

  Future<void> verifyPhoneOtp({
    required String verificationId,
    required String smsCode,
    required String email,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode.trim(),
    );

    await _auth.signInWithCredential(credential);
  }

  Future<void> completePasswordReset({
    required String email,
    required String newPassword,
    required String channel,
  }) async {
    if (channel != 'phone') {
      throw Exception('Use email OTP flow to reset via email.');
    }

    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Phone verification expired. Request a new OTP.');
    }
    await user.updatePassword(newPassword);
    await _auth.signOut();
  }
}

class PhoneOtpRequest {
  const PhoneOtpRequest({
    required this.email,
    required this.phoneE164,
    required this.verificationId,
  });

  final String email;
  final String phoneE164;
  final String verificationId;
}
