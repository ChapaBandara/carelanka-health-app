import 'package:carelanka_app/core/constants/app_routes.dart';
import 'package:carelanka_app/core/constants/app_strings.dart';
import 'package:carelanka_app/core/design/carelanka_gradients.dart';
import 'package:carelanka_app/core/utils/user_data_sync.dart';
import 'package:carelanka_app/providers/auth_provider.dart';
import 'package:carelanka_app/providers/user_data_provider.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _goNext());
  }

  Future<void> _goNext() async {
    final auth = context.read<AuthProvider>();
    final data = context.read<UserDataProvider>();
    await auth.bootstrap();
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
      await auth.loadFromFirebase();
      syncUserDataForProfile(data, auth.profile);
    }
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    final route = FirebaseAuth.instance.currentUser != null ? AppRoutes.dashboard : AppRoutes.welcome;
    Navigator.pushReplacementNamed(context, route);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(gradient: CareLankaGradients.primaryVertical),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 3),
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(Icons.monitor_heart_outlined, color: Colors.white, size: 56),
              ),
              const SizedBox(height: 28),
              const Text(
                'CareLanka',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  AppStrings.tagline,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.white.withValues(alpha: 0.92),
                    height: 1.4,
                  ),
                ),
              ),
              const Spacer(flex: 4),
              Icon(Icons.show_chart, color: Colors.white.withValues(alpha: 0.85), size: 36),
              const SizedBox(height: 24),
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
