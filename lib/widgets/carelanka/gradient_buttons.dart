import 'package:carelanka_app/core/design/carelanka_gradients.dart';
import 'package:flutter/material.dart';

class GradientPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final double height;

  const GradientPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.height = 52,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: CareLankaGradients.primaryHorizontal,
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// White pill with gradient border + gradient label text (Welcome "Create Account").
class GradientOutlinePillButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final double height;

  const GradientOutlinePillButton({
    super.key,
    required this.label,
    this.onPressed,
    this.height = 52,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(28),
        child: Ink(
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: CareLankaGradients.primaryHorizontal,
          ),
          padding: const EdgeInsets.all(2),
          child: Ink(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),
            ),
            child: Center(
              child: ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (bounds) =>
                    CareLankaGradients.primaryHorizontal.createShader(bounds),
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Wide FAB-style "Add Appointment" bar from mockups.
class GradientWideFab extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData icon;

  const GradientWideFab({
    super.key,
    required this.label,
    this.onPressed,
    this.icon = Icons.add,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      elevation: 6,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(28),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: CareLankaGradients.primaryHorizontal,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
