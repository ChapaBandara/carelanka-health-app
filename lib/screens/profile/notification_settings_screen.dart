import 'package:carelanka_app/core/constants/app_colors.dart';
import 'package:carelanka_app/core/firebase/firebase_snackbar.dart';
import 'package:carelanka_app/services/user_service.dart';
import 'package:carelanka_app/widgets/carelanka/gradient_buttons.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool med = true;
  bool appt = true;
  bool alert = true;
  bool email = false;
  bool sms = true;
  bool push = true;
  bool _prefsLoaded = false;

  void _applyPrefs(Map<String, dynamic> prefs) {
    med = prefs['medicationReminders'] as bool? ?? true;
    appt = prefs['appointments'] as bool? ?? true;
    alert = prefs['alerts'] as bool? ?? true;
    email = prefs['email'] as bool? ?? false;
    sms = prefs['sms'] as bool? ?? true;
    push = prefs['push'] as bool? ?? true;
  }

  Map<String, dynamic> _currentPrefs() => {
        'medicationReminders': med,
        'appointments': appt,
        'alerts': alert,
        'push': push,
        'sms': sms,
        'email': email,
      };

  Future<void> _save() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    try {
      await UserService().updateNotificationPreferences(uid, _currentPrefs());
      if (!mounted) return;
      showFirebaseSuccessSnackBar(context, 'Notification preferences saved');
      Navigator.maybePop(context);
    } catch (e) {
      if (!mounted) return;
      showFirebaseErrorSnackBar(context, firebaseErrorMessage(e));
    }
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text('Notification Preferences'),
        centerTitle: true,
      ),
      body: snapshot.connectionState == ConnectionState.waiting
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Channels', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Push notifications'),
                  value: push,
                  onChanged: (v) => setState(() => push = v),
                ),
                SwitchListTile(title: const Text('SMS reminders'), value: sms, onChanged: (v) => setState(() => sms = v)),
                SwitchListTile(title: const Text('Email summaries'), value: email, onChanged: (v) => setState(() => email = v)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text('What we notify you about', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                SwitchListTile(title: const Text('Medication reminders'), value: med, onChanged: (v) => setState(() => med = v)),
                SwitchListTile(title: const Text('Appointments'), value: appt, onChanged: (v) => setState(() => appt = v)),
                SwitchListTile(title: const Text('Alerts & warnings'), value: alert, onChanged: (v) => setState(() => alert = v)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          GradientPrimaryButton(label: 'Save preferences', onPressed: _save),
        ],
      ),
    );
      },
    );
  }
}
