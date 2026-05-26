import 'dart:ui';

import 'package:carelanka_app/core/constants/app_colors.dart';
import 'package:carelanka_app/core/design/carelanka_gradients.dart';
import 'package:flutter/material.dart';

enum CareLankaNotificationVariant { success, error }

/// CareLanka UI — top gradient banner over blurred screen (Login / Register / etc.).
Future<void> showCareLankaNotification(
  BuildContext context, {
  required String title,
  required String subtitle,
  CareLankaNotificationVariant variant = CareLankaNotificationVariant.success,
  Duration displayFor = const Duration(milliseconds: 2500),
  bool belowAppBar = true,
}) {
  return Navigator.of(context, rootNavigator: true).push<void>(
    PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, animation, secondary) {
        return _NotificationOverlayPage(
          title: title,
          subtitle: subtitle,
          variant: variant,
          displayFor: displayFor,
          belowAppBar: belowAppBar,
          animation: animation,
        );
      },
    ),
  );
}

Future<void> showCareLankaSuccessNotification(
  BuildContext context, {
  required String title,
  required String subtitle,
  Duration displayFor = const Duration(milliseconds: 2500),
  bool belowAppBar = true,
}) {
  return showCareLankaNotification(
    context,
    title: title,
    subtitle: subtitle,
    variant: CareLankaNotificationVariant.success,
    displayFor: displayFor,
    belowAppBar: belowAppBar,
  );
}

Future<void> showCareLankaErrorNotification(
  BuildContext context, {
  required String title,
  required String subtitle,
  Duration displayFor = const Duration(milliseconds: 3000),
}) {
  return showCareLankaNotification(
    context,
    title: title,
    subtitle: subtitle,
    variant: CareLankaNotificationVariant.error,
    displayFor: displayFor,
  );
}

/// Gradient banner matching CareLanka UI notification screens.
class CareLankaNotificationBanner extends StatelessWidget {
  const CareLankaNotificationBanner({
    super.key,
    required this.title,
    required this.subtitle,
    this.variant = CareLankaNotificationVariant.success,
  });

  final String title;
  final String subtitle;
  final CareLankaNotificationVariant variant;

  @override
  Widget build(BuildContext context) {
    final isError = variant == CareLankaNotificationVariant.error;
    final gradient = isError
        ? const LinearGradient(
            colors: [Color(0xFFD32F2F), Color(0xFFB71C1C), Color(0xFF7F0000)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          )
        : CareLankaGradients.primaryHorizontal;
    final iconColor = isError ? AppColors.errorRed : const Color(0xFF00A8A8);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: gradient,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                isError ? Icons.close_rounded : Icons.check_rounded,
                color: iconColor,
                size: 24,
                weight: 700,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.95),
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationOverlayPage extends StatefulWidget {
  const _NotificationOverlayPage({
    required this.title,
    required this.subtitle,
    required this.variant,
    required this.displayFor,
    required this.belowAppBar,
    required this.animation,
  });

  final String title;
  final String subtitle;
  final CareLankaNotificationVariant variant;
  final Duration displayFor;
  final bool belowAppBar;
  final Animation<double> animation;

  static const _entranceDuration = Duration(milliseconds: 300);

  @override
  State<_NotificationOverlayPage> createState() => _NotificationOverlayPageState();
}

class _NotificationOverlayPageState extends State<_NotificationOverlayPage> {
  @override
  void initState() {
    super.initState();
    // Keep banner fully visible for [displayFor] after entrance finishes.
    Future<void>.delayed(_NotificationOverlayPage._entranceDuration + widget.displayFor, () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final paddingTop = MediaQuery.paddingOf(context).top;
    final top = widget.belowAppBar ? paddingTop + kToolbarHeight + 12 : paddingTop + 16;
    final entrance = CurvedAnimation(parent: widget.animation, curve: Curves.easeOutCubic);
    final bannerOpacity = CurvedAnimation(
      parent: widget.animation,
      curve: const Interval(0, 0.4, curve: Curves.easeOut),
    );
    final backdropOpacity = CurvedAnimation(
      parent: widget.animation,
      curve: const Interval(0, 0.5, curve: Curves.easeOut),
    );

    return Material(
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          FadeTransition(
            opacity: backdropOpacity,
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 11, sigmaY: 11),
                child: Container(color: Colors.white.withValues(alpha: 0.35)),
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            top: top,
            child: SlideTransition(
              position: Tween<Offset>(begin: const Offset(0, -0.12), end: Offset.zero).animate(entrance),
              child: FadeTransition(
                opacity: bannerOpacity,
                child: CareLankaNotificationBanner(
                  title: widget.title,
                  subtitle: widget.subtitle,
                  variant: widget.variant,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
