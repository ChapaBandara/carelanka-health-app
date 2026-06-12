import 'package:carelanka_app/core/constants/app_colors.dart';
import 'package:carelanka_app/core/design/carelanka_gradients.dart';
import 'package:carelanka_app/widgets/carelanka/carelanka_success_sheet.dart';
import 'package:flutter/material.dart';

/// Post-scan link confirmation — complements CareLanka UI #48 / #49.
class LinkConfirmationScreen extends StatelessWidget {
  const LinkConfirmationScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
            const Text('Link with Kamal Perera?', textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
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
                  await showCareLankaSuccessSheet(
                    context,
                    icon: Icons.person_add_alt_1_rounded,
                    title: 'Invitation Sent!',
                    message: 'Kamal Perera will be notified to confirm the family link.',
                  );
                  if (context.mounted) Navigator.pop(context);
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
