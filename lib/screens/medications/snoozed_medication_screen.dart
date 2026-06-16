import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// CareLanka UI #32 — Snoozed medication countdown screen.
class SnoozedMedicationScreen extends StatefulWidget {
  const SnoozedMedicationScreen({super.key});

  @override
  State<SnoozedMedicationScreen> createState() => _SnoozedMedicationScreenState();
}

class _SnoozedMedicationScreenState extends State<SnoozedMedicationScreen> {
  Timer? _timer;
  Duration _remaining = const Duration(minutes: 15);
  String _remindAt = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startCountdown());
  }

  void _startCountdown() {
    final args = ModalRoute.of(context)?.settings.arguments;
    final map = args is Map ? Map<String, dynamic>.from(args) : <String, dynamic>{};
    final snoozeUntil = map['snoozeUntil'] as DateTime?;
    if (snoozeUntil != null) {
      _remaining = snoozeUntil.difference(DateTime.now());
      if (_remaining.isNegative) _remaining = Duration.zero;
      _remindAt = DateFormat.jm().format(snoozeUntil);
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_remaining.inSeconds > 0) {
          _remaining -= const Duration(seconds: 1);
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _countdown {
    final m = _remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = _remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('reminder_logs')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'snoozed')
          .orderBy('scheduledTime', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        final first = docs.isNotEmpty ? docs.first.data() : <String, dynamic>{};
        final scheduledAt = (first['scheduledTime'] as Timestamp?)?.toDate();
        final remindAt = _remindAt.isNotEmpty
            ? _remindAt
            : (scheduledAt != null ? DateFormat.jm().format(scheduledAt) : '');

        return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0A2463), Color(0xFF008B9C), Color(0xFF00A8A8)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              children: [
                const Spacer(flex: 2),
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8EAF6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.schedule_rounded, size: 48, color: Color(0xFF5C6BC0)),
                ),
                const SizedBox(height: 28),
                const Text(
                  'Reminder Snoozed',
                  style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                Text(
                  "We'll remind you again at $remindAt",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 15),
                ),
                const Spacer(),
                Text(
                  _countdown,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 56,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 2,
                  ),
                ),
                const Spacer(flex: 2),
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.8), width: 1.5),
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  ),
                  child: const Text(
                    'Take it now instead',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
      },
    );
  }
}
