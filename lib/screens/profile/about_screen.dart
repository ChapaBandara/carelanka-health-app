import 'package:carelanka_app/core/constants/app_colors.dart';
import 'package:carelanka_app/core/constants/app_strings.dart';
import 'package:flutter/material.dart';

/// CareLanka UI #61 — About CareLanka screen.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const _features = [
    'Digital health record management',
    'Medication tracking with smart reminders',
    'Drug interaction and allergy detection',
    'Family health profile management',
    'Doctor appointment scheduling',
    'Health summary reports',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 20), onPressed: () => Navigator.maybePop(context)),
        title: const Text('About CareLanka', style: TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: true,
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(height: 1, color: const Color(0xFFEEEEEE))),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: const Color(0xFFE0F7F7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.monitor_heart_outlined, color: AppColors.primaryTeal, size: 44),
            ),
          ),
          const SizedBox(height: 16),
          Text(AppStrings.appName, textAlign: TextAlign.center, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.primaryTeal)),
          const SizedBox(height: 6),
          Text(AppStrings.tagline, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textGrey, fontSize: 14)),
          const SizedBox(height: 4),
          const Text('Version 1.0.0', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textGrey, fontSize: 13)),
          const SizedBox(height: 24),
          _infoCard(
            title: 'What CareLanka Does',
            child: Column(
              children: _features
                  .map(
                    (f) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            margin: const EdgeInsets.only(right: 10, top: 1),
                            decoration: const BoxDecoration(color: Color(0xFFE3F2FD), shape: BoxShape.circle),
                            child: const Icon(Icons.check, size: 14, color: AppColors.primaryTeal),
                          ),
                          Expanded(child: Text(f, style: const TextStyle(color: AppColors.textGrey, height: 1.35))),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 14),
          _infoCard(
            title: 'Developed By',
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('H.M.B.C. Bandara', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                SizedBox(height: 4),
                Text('BSc (Hons) Computer Science', style: TextStyle(color: AppColors.textGrey)),
                Text('University of Bedfordshire', style: TextStyle(color: AppColors.textGrey)),
                SizedBox(height: 12),
                Divider(),
                SizedBox(height: 12),
                Text('Supervised by Dr. Janaka Alawatugoda', style: TextStyle(color: AppColors.textGrey)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(onPressed: () {}, child: const Text('Privacy Policy', style: TextStyle(color: AppColors.primaryTeal, fontWeight: FontWeight.w600))),
              const Text('|', style: TextStyle(color: AppColors.textGrey)),
              TextButton(onPressed: () {}, child: const Text('Terms of Service', style: TextStyle(color: AppColors.primaryTeal, fontWeight: FontWeight.w600))),
            ],
          ),
          const SizedBox(height: 8),
          const Text('© 2026 CareLanka. All rights reserved.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textGrey, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _infoCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
