import 'package:carelanka_app/core/constants/app_colors.dart';
import 'package:carelanka_app/core/constants/app_routes.dart';
import 'package:flutter/material.dart';

/// Three-tab bar from CareLanka UI: Home, Family, Profile.
class CareLankaBottomNav extends StatelessWidget {
  final int currentIndex;
  final void Function(int index)? onShellTap;

  const CareLankaBottomNav({
    super.key,
    required this.currentIndex,
    this.onShellTap,
  });

  void _handleTap(BuildContext context, int index) {
    if (onShellTap != null) {
      onShellTap!(index);
      return;
    }
    final route = switch (index) {
      0 => AppRoutes.dashboard,
      1 => AppRoutes.family,
      _ => AppRoutes.profile,
    };
    Navigator.pushNamedAndRemoveUntil(context, route, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              _item(context, 0, Icons.home_outlined, Icons.home, 'Home'),
              _item(context, 1, Icons.people_outline, Icons.people, 'Family'),
              _item(context, 2, Icons.person_outline, Icons.person, 'Profile'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _item(BuildContext context, int index, IconData outline, IconData filled, String label) {
    final selected = currentIndex == index;
    final color = selected ? AppColors.primaryTeal : AppColors.textGrey;
    return Expanded(
      child: InkWell(
        onTap: () => _handleTap(context, index),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(selected ? filled : outline, color: color, size: 26),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
