import 'package:carelanka_app/core/constants/app_routes.dart';
import 'package:carelanka_app/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Sends already-signed-in users to the dashboard (no login form).
Future<void> redirectToDashboardIfLoggedIn(BuildContext context) async {
  final auth = context.read<AuthProvider>();
  await auth.bootstrap();
  if (!context.mounted) return;
  if (context.read<AuthProvider>().isLoggedIn) {
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.dashboard, (_) => false);
  }
}
