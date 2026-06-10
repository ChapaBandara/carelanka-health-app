import 'dart:convert';

import 'package:carelanka_app/core/constants/emailjs_config.dart';
import 'package:http/http.dart' as http;

/// Sends OTP emails via EmailJS REST API (avoids null accessToken 400 errors).
class EmailJsSendService {
  static const _sendUrl = 'https://api.emailjs.com/api/v1.0/email/send';

  static Future<void> sendOtpEmail({
    required String toEmail,
    required String otpCode,
  }) async {
    if (EmailJsConfig.privateKey.isEmpty) {
      throw Exception(
        'EmailJS Private Key is not configured. '
        'Open EmailJS Dashboard → Account → Security, copy your Private Key, '
        'and set EmailJsConfig.privateKey in lib/core/constants/emailjs_config.dart. '
        'Also enable "Allow API requests from non-browser applications".',
      );
    }

    final body = <String, dynamic>{
      'service_id': EmailJsConfig.serviceId,
      'template_id': EmailJsConfig.templateId,
      'user_id': EmailJsConfig.publicKey,
      'accessToken': EmailJsConfig.privateKey,
      'template_params': <String, String>{
        'to_email': toEmail.trim(),
        'otp_code': otpCode.toString(),
      },
    };

    final response = await http.post(
      Uri.parse(_sendUrl),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) return;

    final message = response.body.trim();
    if (response.statusCode == 403 && message.contains('Private Key')) {
      throw Exception(
        'EmailJS rejected the request: add your Private Key to '
        'lib/core/constants/emailjs_config.dart (Dashboard → Account → Security).',
      );
    }

    throw Exception(
      message.isEmpty ? 'Failed to send verification email (${response.statusCode})' : message,
    );
  }
}
