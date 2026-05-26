import 'package:flutter/material.dart';

/// Gradients aligned with CareLanka UI mockups (teal → navy).
abstract final class CareLankaGradients {
  static const List<Color> primaryColors = [
    Color(0xFF00A8A8),
    Color(0xFF008B9C),
    Color(0xFF001F5F),
  ];

  static LinearGradient primaryHorizontal = const LinearGradient(
    colors: primaryColors,
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static LinearGradient primaryVertical = const LinearGradient(
    colors: [
      Color(0xFF0A2463),
      Color(0xFF00A8A8),
      Color(0xFF0A2463),
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static LinearGradient welcomeHeader = const LinearGradient(
    colors: [
      Color(0xFF00B4C8),
      Color(0xFF004D6B),
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static LinearGradient profileHeader = const LinearGradient(
    colors: [
      Color(0xFF2B6CB0),
      Color(0xFF26A69A),
    ],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static LinearGradient fab = const LinearGradient(
    colors: [
      Color(0xFF001F5F),
      Color(0xFF00A8A8),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
