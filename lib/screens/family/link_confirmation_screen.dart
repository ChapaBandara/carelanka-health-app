import 'package:carelanka_app/core/constants/app_colors.dart';
import 'package:carelanka_app/core/design/carelanka_gradients.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Post-scan link confirmation — complements CareLanka UI #48 / #49.
class LinkConfirmationScreen extends StatelessWidget {
  const LinkConfirmationScreen({super.key});

  Future<void> _confirmLink(BuildContext context, {required String scannedUserId, required String scannedName, required String relationship}) async {
    try {
      final ownerId = FirebaseAuth.instance.currentUser!.uid;
      final docRef = FirebaseFirestore.instance.collection('family_profiles').doc();
      await docRef.set({
        'profileId': docRef.id,
        'ownerId': ownerId,
        'hasOwnAccount': true,
        'linkedUserId': scannedUserId,
        'fullName': scannedName,
        'relationship': relationship,
        'dateOfBirth': null,
        'gender': null,
        'bloodType': null,
        'allergies': <String>[],
        'createdAt': Timestamp.fromDate(DateTime.now()),
      });
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Link created successfully'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final map = args is Map ? Map<String, dynamic>.from(args) : <String, dynamic>{};
    final scannedUserId = map['scannedUserId']?.toString() ?? '';
    final scannedName = map['scannedName']?.toString() ?? 'Family Member';
    final relationship = map['relationship']?.toString() ?? 'Family';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 20), onPressed: () => Navigator.maybePop(context)),
        title: const Text('Confirm link', style: TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Spacer(),
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(color: Color(0xFFE0F7F7), shape: BoxShape.circle),
              child: const Icon(Icons.link, size: 36, color: AppColors.primaryTeal),
            ),
            const SizedBox(height: 18),
            Text('Link with $scannedName?', textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text(
              'They will be able to view shared health information after you both confirm.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textGrey, height: 1.4),
            ),
            const Spacer(),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () async {
                  await _confirmLink(
                    context,
                    scannedUserId: scannedUserId,
                    scannedName: scannedName,
                    relationship: relationship,
                  );
                },
                borderRadius: BorderRadius.circular(14),
                child: Ink(
                  height: 52,
                  width: double.infinity,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), gradient: CareLankaGradients.primaryHorizontal),
                  child: const Center(child: Text('Confirm Link', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
