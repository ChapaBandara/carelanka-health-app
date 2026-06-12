import 'package:carelanka_app/core/constants/app_colors.dart';
import 'package:flutter/material.dart';

class CareLankaSectionHeader extends StatelessWidget {
  const CareLankaSectionHeader(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 8),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: AppColors.textGrey,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class CareLankaSectionCard extends StatelessWidget {
  const CareLankaSectionCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(children: children),
    );
  }
}

class CareLankaSettingsTile extends StatelessWidget {
  const CareLankaSettingsTile({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.trailing,
    this.onTap,
    this.titleColor,
    this.showDivider = true,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color? iconColor;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? titleColor;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          onTap: onTap,
          leading: icon != null ? Icon(icon, color: iconColor ?? AppColors.primaryTeal, size: 22) : null,
          title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: titleColor ?? AppColors.textDark)),
          subtitle: subtitle != null
              ? Text(subtitle!, style: const TextStyle(color: AppColors.textGrey, fontSize: 13))
              : null,
          trailing: trailing ?? (onTap != null ? const Icon(Icons.chevron_right, color: AppColors.textGrey) : null),
        ),
        if (showDivider) const Divider(height: 1, indent: 16, endIndent: 16),
      ],
    );
  }
}
