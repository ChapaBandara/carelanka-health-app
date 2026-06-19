import 'package:carelanka_app/core/constants/app_colors.dart';
import 'package:carelanka_app/core/constants/app_routes.dart';
import 'package:carelanka_app/core/firebase/firebase_snackbar.dart';
import 'package:carelanka_app/providers/auth_provider.dart';
import 'package:carelanka_app/providers/family_provider.dart';
import 'package:carelanka_app/services/family_service.dart';
import 'package:carelanka_app/widgets/carelanka/gradient_buttons.dart';
import 'package:carelanka_app/widgets/empty_list_placeholder.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class FamilyScreen extends StatefulWidget {
  const FamilyScreen({super.key});

  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
  Future<void> _confirmDeleteMember(Map<String, String> member) async {
    final auth = context.read<AuthProvider>();
    final email = auth.profile?.email ?? '';
    final passwordController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete family member?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Do you want to delete ${member['name']}\'s record details permanently? Enter your password to confirm.',
              style: const TextStyle(height: 1.4),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Your password',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.errorRed)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      passwordController.dispose();
      return;
    }

    try {
      await auth.reauthenticateWithPassword(email: email, password: passwordController.text);
      await FamilyService().deleteFamilyMember(member['profileId']!);
      if (!mounted) {
        passwordController.dispose();
        return;
      }
      if (context.read<FamilyProvider>().activeProfileId == member['profileId']) {
        context.read<FamilyProvider>().switchToSelf();
      }
      if (mounted) {
        showFirebaseSuccessSnackBar(context, '${member['name']} removed from family');
      }
    } catch (e) {
      if (mounted) {
        showFirebaseErrorSnackBar(context, firebaseErrorMessage(e));
      }
    } finally {
      passwordController.dispose();
    }
  }

  void _showAccountSwitcher(List<Map<String, String>> members) {
    final family = context.read<FamilyProvider>();
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Switch account', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: const Text('My account', style: TextStyle(fontWeight: FontWeight.w700)),
                  trailing: family.activeMember == null ? const Icon(Icons.check, color: AppColors.primaryTeal) : null,
                  onTap: () {
                    family.switchToSelf();
                    Navigator.pop(ctx);
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      AppRoutes.dashboard,
                      (_) => false,
                    );
                  },
                ),
                for (final m in members)
                  ListTile(
                    leading: CircleAvatar(child: Text(m['initials'] ?? '?')),
                    title: Text(m['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(m['meta'] ?? ''),
                    trailing: family.activeProfileId == m['profileId']
                        ? const Icon(Icons.check, color: AppColors.primaryTeal)
                        : null,
                    onTap: () {
                      family.switchToMember(m);
                      Navigator.pop(ctx);
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        AppRoutes.dashboard,
                        (_) => false,
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final familyProvider = context.watch<FamilyProvider>();
    final isDependent = auth.profile?.isDependent ?? false;
    final userId = FirebaseAuth.instance.currentUser!.uid;

    return StreamBuilder<List<Map<String, String>>>(
      stream: FamilyService().watchFamilyMaps(userId),
      builder: (context, snapshot) {
        final familyMembers = snapshot.data ?? [];

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('Family Health'),
            centerTitle: true,
            actions: [
              if (!isDependent && familyMembers.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.swap_horiz),
                  tooltip: 'Switch account',
                  onPressed: () => _showAccountSwitcher(familyMembers),
                ),
            ],
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (familyProvider.isViewingFamilyMember) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F7F7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.visibility, color: AppColors.primaryTeal, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Viewing: ${familyProvider.activeDisplayName}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        TextButton(
                          onPressed: () => familyProvider.switchToSelf(),
                          child: const Text('Switch back'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (isDependent) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.infoBannerBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFB8D4E8)),
                    ),
                    child: Text(
                      'Your profile is linked to ${auth.profile?.guardianName ?? 'a family account'}. Health data is managed by the primary account holder.',
                      style: TextStyle(color: Colors.blueGrey.shade800, height: 1.4, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('Linked account', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  if (familyMembers.isEmpty)
                    const EmptyListPlaceholder(icon: Icons.link_off, title: 'No family link found')
                  else
                    ...familyMembers.map((m) => _memberTile(context, m, canDelete: false)),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.infoBannerBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFB8D4E8)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline, color: AppColors.navy),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Manage medications, health records, allergies, and appointments for your family members from one account.',
                            style: TextStyle(color: Colors.blueGrey.shade800, height: 1.4, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('Link Existing CareLanka Account', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  const Text(
                    'If your family member already uses CareLanka, scan their QR code to securely connect both accounts.',
                    style: TextStyle(color: AppColors.textGrey, height: 1.4),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryTeal,
                      side: const BorderSide(color: AppColors.navy, width: 1.2),
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => Navigator.pushNamed(context, AppRoutes.qrScanner),
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Scan Family QR Code', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 28),
                  const Text('Create Dependent Profile', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  const Text(
                    'For children, elderly parents, or family members who do not use a smartphone, create a profile and manage their health data from your account.',
                    style: TextStyle(color: AppColors.textGrey, height: 1.4),
                  ),
                  const SizedBox(height: 14),
                  GradientPrimaryButton(
                    height: 48,
                    label: 'Create Dependent Profile',
                    onPressed: () => Navigator.pushNamed(context, AppRoutes.addDependent),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Divider(height: 1),
                  ),
                  const Text('Your Family Members', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  if (familyMembers.isEmpty)
                    const EmptyListPlaceholder(
                      icon: Icons.people_outline,
                      title: 'No family members yet',
                      subtitle: 'Scan a QR code or create a dependent profile to get started.',
                    )
                  else
                    ...familyMembers.map((m) => _memberTile(context, m, canDelete: true)),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _memberTile(BuildContext context, Map<String, String> member, {required bool canDelete}) {
    final linked = member['type'] != 'dependent';
    final card = _memberCard(
      context,
      member,
      linked,
    );

    if (!canDelete) return Padding(padding: const EdgeInsets.only(bottom: 12), child: card);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Dismissible(
        key: ValueKey(member['profileId']),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(color: AppColors.errorRed, borderRadius: BorderRadius.circular(14)),
          child: const Icon(Icons.delete_outline, color: Colors.white),
        ),
        confirmDismiss: (_) async {
          await _confirmDeleteMember(member);
          return false;
        },
        child: card,
      ),
    );
  }

  Widget _memberCard(BuildContext context, Map<String, String> member, bool linked) {
    final tag1 = member['tag1'] ?? '';
    final tag2 = member['tag2'] ?? '';
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          context.read<FamilyProvider>().switchToMember(member);
          Navigator.pushNamed(context, AppRoutes.familyDetail, arguments: member);
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: linked ? const Color(0xFFB2DFDB) : const Color(0xFFBBDEFB),
                radius: 26,
                child: Text(member['initials'] ?? '?', style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(member['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(member['meta'] ?? '', style: const TextStyle(color: AppColors.textGrey, fontSize: 13)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (tag1.isNotEmpty) _greyChip(tag1),
                        if (tag2.isNotEmpty) _greyChip(tag2),
                        linked
                            ? Chip(
                                avatar: const Icon(Icons.qr_code_scanner, size: 16, color: Color(0xFF2E7D32)),
                                label: const Text('Linked Account', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                backgroundColor: const Color(0xFFE8F5E9),
                                side: BorderSide.none,
                              )
                            : Chip(
                                avatar: const Icon(Icons.person_outline, size: 16),
                                label: const Text('Dependent Profile', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                backgroundColor: const Color(0xFFE3F2FD),
                                side: BorderSide.none,
                              ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textGrey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _greyChip(String t) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F3F5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(t, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}
