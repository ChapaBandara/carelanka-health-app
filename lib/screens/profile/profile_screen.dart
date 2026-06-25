import 'package:carelanka_app/core/constants/app_colors.dart';
import 'package:carelanka_app/core/constants/app_routes.dart';
import 'package:carelanka_app/core/design/carelanka_gradients.dart';
import 'package:carelanka_app/core/firebase/firebase_snackbar.dart';
import 'package:carelanka_app/core/utils/active_uid.dart';
import 'package:carelanka_app/providers/auth_provider.dart';
import 'package:carelanka_app/providers/family_provider.dart';
import 'package:carelanka_app/providers/user_data_provider.dart';
import 'package:carelanka_app/services/family_service.dart';
import 'package:carelanka_app/services/health_record_service.dart';
import 'package:carelanka_app/services/illness_service.dart';
import 'package:carelanka_app/services/medication_service.dart';
import 'package:carelanka_app/widgets/carelanka/profile_avatar.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

Future<void> _handleDeleteAccount(BuildContext context) async {
  final auth = context.read<AuthProvider>();
  final email = auth.profile?.email ?? '';
  if (email.isEmpty) {
    showFirebaseErrorSnackBar(context, 'Account email not found.');
    return;
  }

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete account?'),
      content: const Text('This permanently removes your CareLanka account and health data. This action cannot be undone.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Continue', style: TextStyle(color: AppColors.errorRed, fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  final passwordController = TextEditingController();
  final password = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Confirm with password'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Enter the password for $email to delete your account.', style: TextStyle(color: Colors.grey.shade700)),
          const SizedBox(height: 16),
          TextField(
            controller: passwordController,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.errorRed),
          onPressed: () => Navigator.pop(ctx, passwordController.text),
          child: const Text('Delete account'),
        ),
      ],
    ),
  );
  passwordController.dispose();
  if (password == null || password.isEmpty || !context.mounted) return;

  try {
    await auth.deleteAccount(password: password);
  } catch (e) {
    if (!context.mounted) return;
    if (!auth.justDeletedAccount) {
      showFirebaseErrorSnackBar(context, firebaseErrorMessage(e));
      return;
    }
  }

  if (!context.mounted) return;
  context.read<UserDataProvider>().resetForOwner();
  auth.justDeletedAccount = true;
  Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil(AppRoutes.welcome, (_) => false);
}

/// CareLanka UI #50 — My Profile screen.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final p = auth.profile;
    final isDependent = p?.isDependent ?? false;
    // userId for profile header/family card (always own account)
    final userId = FirebaseAuth.instance.currentUser!.uid;

    final menu = isDependent
        ? [
            (Icons.lock_outline, 'Privacy and Security', AppRoutes.privacy),
            (Icons.help_outline, 'Help and Support', AppRoutes.help),
            (Icons.info_outline, 'About CareLanka', AppRoutes.about),
          ]
        : [
            (Icons.shield_outlined, 'Allergy Profile', AppRoutes.allergies),
            (Icons.notifications_outlined, 'Notification Preferences', AppRoutes.notificationSettings),
            (Icons.lock_outline, 'Privacy and Security', AppRoutes.privacy),
            (Icons.help_outline, 'Help and Support', AppRoutes.help),
            (Icons.info_outline, 'About CareLanka', AppRoutes.about),
          ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Profile', style: TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: true,
        actions: [
          if (!isDependent)
            IconButton(onPressed: () => Navigator.pushNamed(context, AppRoutes.myQr), icon: const Icon(Icons.qr_code_2)),
          IconButton(onPressed: () => Navigator.pushNamed(context, AppRoutes.editProfile), icon: const Icon(Icons.edit_outlined)),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: CareLankaGradients.profileHeader,
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 16, offset: const Offset(0, 8))],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                    child: ProfileAvatar(
                      radius: 44,
                      imageUrl: p?.profileImageUrl,
                      initials: p?.initials ?? '?',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(p?.fullName ?? '', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(p?.email ?? '', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  if (p?.phone.isNotEmpty == true)
                    Text('+94 ${p!.phone}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
            if (!isDependent) ...[
              const SizedBox(height: 16),
              Consumer<FamilyProvider>(
                builder: (context, _, _) {
                  final statsUid = context.activeUid;
                  return StreamBuilder(
                    stream: MedicationService().watchMedications(statsUid),
                    builder: (context, medSnap) {
                      return StreamBuilder(
                        stream: HealthRecordService().watchRecordMaps(statsUid),
                        builder: (context, recSnap) {
                          return StreamBuilder(
                            stream: FamilyService().watchFamilyMaps(statsUid),
                            builder: (context, famSnap) {
                              return StreamBuilder(
                                stream: IllnessService().watchIllnessMaps(statsUid),
                                builder: (context, illnessSnap) {
                                final activeIllnessIds = (illnessSnap.data ?? [])
                                    .where((i) => i['status'] != 'completed')
                                    .map((i) => i['illnessId'] ?? '')
                                    .toSet();

                                final activeMedCount = (medSnap.data ?? [])
                                    .where((m) =>
                                        m['active'] == true &&
                                        activeIllnessIds.contains(m['illnessId'] ?? ''))
                                    .length;
                                final recCount = recSnap.data?.length ?? 0;
                                final famCount = famSnap.data?.length ?? 0;
                                return Row(
                                  children: [
                                    Expanded(child: _statCard(Icons.medication_rounded, const Color(0xFFBBDEFB), '$activeMedCount', 'Active Meds')),
                                    const SizedBox(width: 10),
                                    Expanded(child: _statCard(Icons.folder_open, const Color(0xFFC8E6C9), '$recCount', 'Records')),
                                    const SizedBox(width: 10),
                                    Expanded(child: _statCard(Icons.people_outline, const Color(0xFFFFF59D), '$famCount', 'Family')),
                                  ],
                                );
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                );
                },
              ),
            ],
            const SizedBox(height: 16),
            Card(
              elevation: 0.3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  for (var i = 0; i < menu.length; i++) ...[
                    ListTile(
                      leading: Icon(menu[i].$1, color: AppColors.textDark),
                      title: Text(menu[i].$2, style: const TextStyle(fontWeight: FontWeight.w500)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.pushNamed(context, menu[i].$3),
                    ),
                    if (i < menu.length - 1) const Divider(height: 1),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            StreamBuilder<List<Map<String, String>>>(
              stream: FamilyService().watchFamilyMaps(userId),
              builder: (context, snapshot) {
                final members = snapshot.data ?? [];
                return Card(
                  elevation: 0.3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isDependent ? 'Linked primary account' : 'Linked Family Accounts',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.navy),
                        ),
                        const SizedBox(height: 12),
                        if (members.isEmpty)
                          Text(
                            isDependent ? 'No link on file.' : 'No linked accounts yet.',
                            style: const TextStyle(color: AppColors.textGrey),
                          )
                        else
                          ...members.map((m) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _linkedRow(m['initials'] ?? '?', const Color(0xFFB2DFDB), m['name'] ?? '', m['meta'] ?? ''),
                              )),
                        const SizedBox(height: 12),
                        Center(
                          child: TextButton(
                            onPressed: () => Navigator.pushNamed(context, AppRoutes.family),
                            child: const Text('Manage Account Links', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.navy)),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.errorRed,
                side: const BorderSide(color: AppColors.errorRed),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () async {
                context.read<UserDataProvider>().resetForOwner();
                await context.read<AuthProvider>().signOut();
                if (context.mounted) {
                  Navigator.pushNamedAndRemoveUntil(context, AppRoutes.welcome, (_) => false);
                }
              },
              child: const Text('Logout', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            TextButton(
              onPressed: () => _handleDeleteAccount(context),
              child: const Text('Delete Account', style: TextStyle(color: AppColors.errorRed, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _statCard(IconData icon, Color circleBg, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          CircleAvatar(backgroundColor: circleBg, radius: 22, child: Icon(icon, color: AppColors.navy, size: 22)),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
        ],
      ),
    );
  }

  Widget _linkedRow(String initials, Color bg, String name, String rel) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE0E0E0)), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: bg, child: Text(initials, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(rel, style: const TextStyle(color: AppColors.textGrey, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
