import 'package:carelanka_app/core/constants/app_colors.dart';
import 'package:carelanka_app/core/design/carelanka_gradients.dart';
import 'package:flutter/material.dart';

/// CareLanka UI bottom-sheet success modals (#49, #55, etc.).
Future<void> showCareLankaSuccessSheet(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String message,
  String? chipLabel,
  String? note,
  String primaryLabel = 'Done',
  VoidCallback? onPrimary,
  String? secondaryLabel,
  VoidCallback? onSecondary,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFE0F7F7),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: AppColors.primaryTeal.withValues(alpha: 0.2), blurRadius: 12, offset: const Offset(0, 4)),
                ],
              ),
              child: Icon(icon, color: AppColors.primaryTeal, size: 36),
            ),
            const SizedBox(height: 18),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textGrey, fontSize: 14, height: 1.45),
            ),
            if (chipLabel != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.primaryTeal),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(chipLabel, style: const TextStyle(color: AppColors.primaryTeal, fontWeight: FontWeight.w700)),
              ),
            ],
            if (note != null) ...[
              const SizedBox(height: 12),
              Text(
                note,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.primaryTeal,
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  height: 1.4,
                ),
              ),
            ],
            const SizedBox(height: 24),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  Navigator.pop(ctx);
                  onPrimary?.call();
                },
                borderRadius: BorderRadius.circular(14),
                child: Ink(
                  height: 52,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: CareLankaGradients.primaryHorizontal,
                  ),
                  child: Center(
                    child: Text(primaryLabel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                  ),
                ),
              ),
            ),
            if (secondaryLabel != null) ...[
              const SizedBox(height: 10),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  onSecondary?.call();
                },
                child: Text(secondaryLabel, style: const TextStyle(color: AppColors.textGrey, fontWeight: FontWeight.w600)),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
