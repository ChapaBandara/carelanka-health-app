import 'package:carelanka_app/core/constants/app_colors.dart';
import 'package:carelanka_app/core/design/carelanka_gradients.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:carelanka_app/providers/auth_provider.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// CareLanka UI #52 — My Profile QR Code screen.
class MyQrScreen extends StatelessWidget {
  const MyQrScreen({super.key});

  Future<String> _resolveName() async {
    final user = FirebaseAuth.instance.currentUser!;
    final displayName = user.displayName?.trim() ?? '';
    if (displayName.isNotEmpty) return displayName;

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final data = userDoc.data();
    final name = data?['fullName']?.toString().trim() ?? '';
    return name.isNotEmpty ? name : 'CareLanka User';
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthProvider>().profile;
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final shortId = uid.length > 8 ? uid.substring(0, 8).toUpperCase() : uid.toUpperCase();

    return FutureBuilder<String>(
      future: _resolveName(),
      builder: (context, snapshot) {
        final name = snapshot.data?.trim().isNotEmpty == true
            ? snapshot.data!
            : (profile?.fullName.trim().isNotEmpty == true ? profile!.fullName : 'CareLanka User');
        final qrValue = 'carelanka://link?userId=$uid&name=${Uri.encodeComponent(name)}';

        return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text('My QR Code', style: TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFEEEEEE)),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'Share Your QR Code',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.navy),
            ),
            const SizedBox(height: 8),
            const Text(
              'Ask your family member to scan this from their CareLanka app to link accounts.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textGrey, fontSize: 14, height: 1.45),
            ),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.primaryTeal, width: 2),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFEEEEEE)),
                    ),
                    child: QrImageView(
                      data: qrValue,
                      version: QrVersions.auto,
                      size: 200,
                      eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: AppColors.navy),
                      dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: AppColors.navy),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                  const SizedBox(height: 4),
                  Text('CareLanka ID: $shortId', style: const TextStyle(color: AppColors.textGrey, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('How to link:', style: TextStyle(color: AppColors.primaryTeal, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  for (final entry in [
                    (1, 'Family member opens CareLanka app'),
                    (2, 'Goes to Family Health → Scan Family QR Code'),
                    (3, 'Points camera at this QR code'),
                    (4, 'Both parties confirm the link request'),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            margin: const EdgeInsets.only(right: 10, top: 1),
                            decoration: const BoxDecoration(color: AppColors.primaryTeal, shape: BoxShape.circle),
                            alignment: Alignment.center,
                            child: Text(
                              '${entry.$1}',
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                            ),
                          ),
                          Expanded(child: Text(entry.$2, style: const TextStyle(color: Color(0xFF2E7D32), fontSize: 13, height: 1.35))),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {},
                borderRadius: BorderRadius.circular(14),
                child: Ink(
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: CareLankaGradients.primaryHorizontal,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.share_outlined, color: Colors.white),
                      SizedBox(width: 8),
                      Text('Share QR Code', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done', style: TextStyle(color: AppColors.textGrey, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
      },
    );
  }
}
