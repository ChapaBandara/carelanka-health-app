import 'package:carelanka_app/core/constants/app_colors.dart';
import 'package:carelanka_app/core/firebase/firebase_snackbar.dart';
import 'package:carelanka_app/services/user_service.dart';
import 'package:carelanka_app/widgets/carelanka/success_notification_overlay.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// CareLanka UI #56 — Notification Preferences screen.
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool med = true;
  bool missed = true;
  bool appt = true;
  bool checkup = true;
  bool conflict = true;
  bool weekly = true;
  bool lowStock = true;
  bool quietHours = true;
  String snooze = '15 minutes';
  bool _prefsLoaded = false;

  void _applyPrefs(Map<String, dynamic> prefs) {
    med = prefs['medicationReminders'] as bool? ?? true;
    missed = prefs['missedDoseAlerts'] as bool? ?? true;
    appt = prefs['appointments'] as bool? ?? true;
    checkup = prefs['checkupSuggestions'] as bool? ?? true;
    conflict = prefs['drugConflictWarnings'] as bool? ?? true;
    weekly = prefs['weeklySummary'] as bool? ?? true;
    lowStock = prefs['lowStockReminders'] as bool? ?? true;
    quietHours = prefs['quietHours'] as bool? ?? true;
    snooze = prefs['snoozeDuration'] as String? ?? '15 minutes';
  }

  Map<String, dynamic> _currentPrefs() => {
        'medicationReminders': med,
        'missedDoseAlerts': missed,
        'appointments': appt,
        'checkupSuggestions': checkup,
        'drugConflictWarnings': conflict,
        'weeklySummary': weekly,
        'lowStockReminders': lowStock,
        'quietHours': quietHours,
        'snoozeDuration': snooze,
      };

  Future<void> _save() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    try {
      await UserService().updateNotificationPreferences(uid, _currentPrefs());
      if (!mounted) return;
      await showCareLankaSuccessNotification(
        context,
        title: 'Preferences saved',
        subtitle: 'Your notification settings have been updated.',
      );
      if (mounted) Navigator.maybePop(context);
    } catch (e) {
      if (!mounted) return;
      showFirebaseErrorSnackBar(context, firebaseErrorMessage(e));
    }
  }

  Widget _toggleTile(String title, String subtitle, bool value, ValueChanged<bool>? onChanged) {
    return Column(
      children: [
        SwitchListTile(
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(subtitle, style: const TextStyle(color: AppColors.textGrey, fontSize: 13)),
          value: value,
          activeThumbColor: AppColors.primaryTeal,
          onChanged: onChanged,
        ),
        const Divider(height: 1),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return FutureBuilder<Map<String, dynamic>?>(
      future: UserService().getNotificationPreferences(uid),
      builder: (context, snapshot) {
        if (!_prefsLoaded && snapshot.connectionState == ConnectionState.done && snapshot.data != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || _prefsLoaded) return;
            setState(() {
              _applyPrefs(snapshot.data!);
              _prefsLoaded = true;
            });
          });
        }

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 20), onPressed: () => Navigator.maybePop(context)),
            title: const Text('Notification Preferences', style: TextStyle(fontWeight: FontWeight.w700)),
            centerTitle: true,
          ),
          body: snapshot.connectionState == ConnectionState.waiting
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      child: Column(
                        children: [
                          _toggleTile('Medication Reminders', 'Get reminded when it is time to take your medication', med, (v) => setState(() => med = v)),
                          _toggleTile('Missed Dose Alerts', 'Get alerted when a dose is missed', missed, (v) => setState(() => missed = v)),
                          _toggleTile('Appointment Reminders', 'Get reminders before doctor appointments', appt, (v) => setState(() => appt = v)),
                          _toggleTile('Checkup Suggestions', 'Get suggestions when you are overdue for a checkup', checkup, (v) => setState(() => checkup = v)),
                          _toggleTile('Drug Conflict Warnings', 'Always receive safety warnings (cannot disable)', conflict, null),
                          _toggleTile('Weekly Health Summary', 'Receive a weekly summary of your health data', weekly, (v) => setState(() => weekly = v)),
                          _toggleTile('Low Stock Reminders', 'Get reminded when a medication stock is running low', lowStock, (v) => setState(() => lowStock = v)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      child: ListTile(
                        title: const Text('Snooze Duration', style: TextStyle(fontWeight: FontWeight.w600)),
                        trailing: DropdownButton<String>(
                          value: snooze,
                          underline: const SizedBox.shrink(),
                          items: const [
                            DropdownMenuItem(value: '15 minutes', child: Text('15 minutes')),
                            DropdownMenuItem(value: '30 minutes', child: Text('30 minutes')),
                          ],
                          onChanged: (v) => setState(() => snooze = v ?? snooze),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Enable Quiet Hours', style: TextStyle(fontWeight: FontWeight.w600)),
                              value: quietHours,
                              activeThumbColor: AppColors.primaryTeal,
                              onChanged: (v) => setState(() => quietHours = v),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('From', style: TextStyle(color: AppColors.textGrey, fontSize: 12)),
                                      const SizedBox(height: 6),
                                      TextField(
                                        readOnly: true,
                                        decoration: InputDecoration(
                                          hintText: '10:00 PM',
                                          suffixIcon: const Icon(Icons.access_time, size: 18),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('To', style: TextStyle(color: AppColors.textGrey, fontSize: 12)),
                                      const SizedBox(height: 6),
                                      TextField(
                                        readOnly: true,
                                        decoration: InputDecoration(
                                          hintText: '07:00 AM',
                                          suffixIcon: const Icon(Icons.access_time, size: 18),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Row(
                              children: [
                                Icon(Icons.info_outline, size: 16, color: AppColors.textGrey),
                                SizedBox(width: 6),
                                Expanded(child: Text('No reminders sent during quiet hours', style: TextStyle(color: AppColors.textGrey, fontSize: 12, fontStyle: FontStyle.italic))),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.navy,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Save preferences', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
        );
      },
    );
  }
}
