import 'package:carelanka_app/core/constants/app_colors.dart';
import 'package:carelanka_app/core/constants/app_routes.dart';
import 'package:carelanka_app/widgets/carelanka/carelanka_section_card.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// CareLanka UI #57 — Privacy and Security screen.
class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  bool twoFactor = false;
  bool camera = true;
  bool notifications = true;
  bool storage = true;

  String get _sessionSubtitle {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'Not signed in';
    return '1 device logged in';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 20), onPressed: () => Navigator.maybePop(context)),
        title: const Text('Privacy and Security', style: TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const CareLankaSectionHeader('Account Security'),
          CareLankaSectionCard(
            children: [
              CareLankaSettingsTile(
                icon: Icons.lock_outline,
                title: 'Change Password',
                onTap: () => Navigator.pushNamed(context, AppRoutes.changePassword),
              ),
              CareLankaSettingsTile(
                icon: Icons.shield_outlined,
                title: 'Two-Factor Authentication',
                subtitle: twoFactor ? 'Enabled' : 'Not enabled',
                trailing: Switch(value: twoFactor, activeThumbColor: AppColors.primaryTeal, onChanged: (v) => setState(() => twoFactor = v)),
                showDivider: true,
              ),
              CareLankaSettingsTile(
                icon: Icons.computer_outlined,
                title: 'Active Sessions',
                subtitle: _sessionSubtitle,
                trailing: TextButton(onPressed: () {}, child: const Text('Log out all other devices', style: TextStyle(color: AppColors.errorRed, fontSize: 12))),
                showDivider: false,
              ),
            ],
          ),
          const CareLankaSectionHeader('Your Data'),
          CareLankaSectionCard(
            children: [
              const CareLankaSettingsTile(icon: Icons.download_outlined, title: 'Download My Data'),
              CareLankaSettingsTile(
                icon: Icons.delete_outline,
                title: 'Delete All My Health Records',
                titleColor: AppColors.errorRed,
                iconColor: AppColors.errorRed,
                trailing: const SizedBox.shrink(),
              ),
              CareLankaSettingsTile(
                icon: Icons.person_remove_outlined,
                title: 'Delete My Account',
                titleColor: AppColors.errorRed,
                iconColor: AppColors.errorRed,
                trailing: const SizedBox.shrink(),
                showDivider: false,
              ),
            ],
          ),
          const CareLankaSectionHeader('Data Sharing'),
          CareLankaSectionCard(
            children: [
              CareLankaSettingsTile(
                icon: Icons.people_outline,
                title: 'Family Account Links',
                onTap: () => Navigator.pushNamed(context, AppRoutes.family),
                showDivider: false,
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 18, color: AppColors.primaryTeal),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Only you and family members you explicitly link can access your records. CareLanka does not share your data with third parties.',
                    style: TextStyle(color: AppColors.textGrey, fontSize: 13, height: 1.45),
                  ),
                ),
              ],
            ),
          ),
          const CareLankaSectionHeader('App Permissions'),
          CareLankaSectionCard(
            children: [
              CareLankaSettingsTile(
                icon: Icons.camera_alt_outlined,
                iconColor: AppColors.textGrey,
                title: 'Camera',
                trailing: Switch(value: camera, activeThumbColor: AppColors.primaryTeal, onChanged: (v) => setState(() => camera = v)),
              ),
              CareLankaSettingsTile(
                icon: Icons.notifications_none_outlined,
                iconColor: AppColors.textGrey,
                title: 'Notifications',
                trailing: Switch(value: notifications, activeThumbColor: AppColors.primaryTeal, onChanged: (v) => setState(() => notifications = v)),
              ),
              CareLankaSettingsTile(
                icon: Icons.folder_outlined,
                iconColor: AppColors.textGrey,
                title: 'Storage',
                trailing: Switch(value: storage, activeThumbColor: AppColors.primaryTeal, onChanged: (v) => setState(() => storage = v)),
                showDivider: false,
              ),
            ],
          ),
          const CareLankaSectionHeader('Legal'),
          CareLankaSectionCard(
            children: [
              const CareLankaSettingsTile(title: 'Privacy Policy', trailing: Icon(Icons.open_in_new, size: 18, color: AppColors.textGrey)),
              const CareLankaSettingsTile(title: 'Terms of Service', trailing: Icon(Icons.open_in_new, size: 18, color: AppColors.textGrey)),
              const CareLankaSettingsTile(title: 'Cookie Policy', trailing: Icon(Icons.open_in_new, size: 18, color: AppColors.textGrey), showDivider: false),
            ],
          ),
        ],
      ),
    );
  }
}
