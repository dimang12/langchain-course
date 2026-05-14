import 'dart:ui';
import 'package:flutter/material.dart';

/// Glass workspace design tokens — "soft dawn" palette.
/// Translated from the HTML prototype's oklch color system.
class GlassTheme {
  GlassTheme._();

  // ── Accent (lavender, hue 262) ──
  static const accent = Color(0xFF7C5CFF);
  static const accentSoft = Color(0xFFCBBFFF);
  static const accentDeep = Color(0xFF4A2DB3);

  // ── Ink hierarchy ──
  static const ink = Color(0xFF1E1B2E);
  static const ink2 = Color(0xFF5A5571);
  static const ink3 = Color(0xFF8D89A0);

  // ── Glass surfaces — high opacity for crisp frosted look ──
  static const glassBg = Color(0xF2FCFBFF); // 95% opaque frosted white
  static const glassBg2 = Color(0xB3FCFBFF); // ~70%
  static const glassBorder = Color(0xB3FFFFFF); // white 70%
  static const line = Color(0x80E0DDE8); // subtle separator

  // ── Canvas ──
  static const canvas = Color(0xFFF5F3FA);
  static const canvasGradientStart = Color(0xFFF7F5FC);
  static const canvasGradientEnd = Color(0xFFF2EFFB);

  // ── Glass constants ──
  static const double blurSigma = 14.0;
  static const double panelRadius = 22.0;
  static const double cardRadius = 18.0;
  static const double buttonRadius = 14.0;
  static const double chipRadius = 9.0;
  static const double inputRadius = 12.0;

  // ── Rail ──
  static const double railWidth = 76.0;
  static const double sidebarWidth = 280.0;

  // ── Glass panel decoration ──
  // Smooth double-border: inner white highlight + outer gray, two-layer shadow
  static BoxDecoration glassDecoration({
    double radius = panelRadius,
    Color? background,
  }) {
    return BoxDecoration(
      color: background ?? glassBg,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: glassBorder, width: 1),
      boxShadow: const [
        // Tight top highlight
        BoxShadow(color: Color(0x20302050), blurRadius: 1, offset: Offset(0, 1)),
        // Smooth diffused shadow
        BoxShadow(color: Color(0x20302050), blurRadius: 30, offset: Offset(0, 15)),
      ],
    );
  }

  /// Lighter inner glass decoration (for toolbars, search boxes)
  static BoxDecoration glassInnerDecoration({
    double radius = buttonRadius,
  }) {
    return BoxDecoration(
      color: const Color(0xB3FFFFFF),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: glassBorder, width: 1),
      boxShadow: const [
        BoxShadow(
          color: Color(0x20302050),
          blurRadius: 12,
          spreadRadius: -2,
          offset: Offset(0, 4),
        ),
      ],
    );
  }

  /// Backdrop blur filter for glass effect
  static ImageFilter get blurFilter =>
      ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma);

  // ── Blob colors for animated background ──
  static const blobColors = [
    Color(0xDDF4A870), // warm peach/orange
    Color(0xCC70C0E8), // cool cyan
    Color(0xEEA880FF), // lavender
    Color(0xCC80E8B0), // mint green
  ];
}
