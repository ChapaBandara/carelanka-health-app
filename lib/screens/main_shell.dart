import 'package:carelanka_app/screens/family/family_screen.dart';
import 'package:carelanka_app/screens/home/dashboard_screen.dart';
import 'package:carelanka_app/screens/profile/profile_screen.dart';
import 'package:carelanka_app/services/checkup_service.dart';
import 'package:carelanka_app/widgets/carelanka/carelanka_bottom_nav.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// CareLanka shell: Home, Family, Profile (matches UI folder bottom navigation).
class MainShell extends StatefulWidget {
  final int initialIndex;
  const MainShell({super.key, this.initialIndex = 0});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, 2);
    WidgetsBinding.instance.addPostFrameCallback((_) => _evaluateCheckupReminder());
  }

  Future<void> _evaluateCheckupReminder() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    await CheckupService().evaluateForUser(userId);
  }

  @override
  Widget build(BuildContext context) {
    const screens = [
      DashboardScreen(),
      FamilyScreen(),
      ProfileScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: CareLankaBottomNav(
        currentIndex: _index,
        onShellTap: (i) => setState(() => _index = i),
      ),
    );
  }
}
