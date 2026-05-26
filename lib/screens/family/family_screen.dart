import 'package:carelanka_app/core/constants/app_colors.dart';
import 'package:carelanka_app/core/constants/app_routes.dart';
import 'package:carelanka_app/providers/auth_provider.dart';
import 'package:carelanka_app/services/family_service.dart';
import 'package:carelanka_app/widgets/carelanka/gradient_buttons.dart';
import 'package:carelanka_app/widgets/empty_list_placeholder.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class FamilyScreen extends StatelessWidget {
  const FamilyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isDependent = auth.profile?.isDependent ?? false;
    final userId = FirebaseAuth.instance.currentUser!.uid;

    return StreamBuilder<List<Map<String, String>>>(
      stream: FamilyService().watchFamilyMaps(userId),
      builder: (context, snapshot) {
        final familyMembers = snapshot.data ?? [];

        return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Family Health'), centerTitle: true),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
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
                const EmptyListPlaceholder(
                  icon: Icons.link_off,
                  title: 'No family link found',
                )
              else
                ...familyMembers.map((m) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _memberCard(
                        context,
                        m['initials'] ?? '?',
                        const Color(0xFFB2DFDB),
                        m['name'] ?? '',
                        m['meta'] ?? '',
                        '',
                        '',
                        true,
                      ),
                    )),
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
              const SizedBox(height: 8),
              Text(
                'Ask your family member to open Profile → My QR Code.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
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
                ...familyMembers.map((m) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _memberCard(
                        context,
                        m['initials'] ?? '?',
                        const Color(0xFFBBDEFB),
                        m['name'] ?? '',
                        m['meta'] ?? '',
                        m['tag1'] ?? '',
                        m['tag2'] ?? '',
                        m['type'] != 'dependent',
                      ),
                    )),
            ],
          ],
        ),
      ),
    );
      },
    );
  }

  Widget _memberCard(
    BuildContext context,
    String initials,
    Color bg,
    String name,
    String meta,
    String tag1,
    String tag2,
    bool linked,
  ) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.pushNamed(context, AppRoutes.familyDetail),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(backgroundColor: bg, radius: 26, child: Text(initials, style: const TextStyle(fontWeight: FontWeight.w800))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(meta, style: const TextStyle(color: AppColors.textGrey, fontSize: 13)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: [
                        _greyChip(tag1),
                        _greyChip(tag2),
                        linked
                            ? Chip(
                                avatar: const Icon(Icons.link, size: 16, color: Color(0xFF2E7D32)),
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
              Icon(Icons.more_vert, color: Colors.grey.shade500),
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
