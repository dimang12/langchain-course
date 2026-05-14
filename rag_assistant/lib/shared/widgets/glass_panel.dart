import 'package:flutter/material.dart';
import '../theme/glass_theme.dart';

/// A panel with subtle shadow and border.
class GlassPanel extends StatelessWidget {
  final Widget child;
  final double radius;
  final Color? background;
  final EdgeInsetsGeometry? padding;

  const GlassPanel({
    super.key,
    required this.child,
    this.radius = GlassTheme.panelRadius,
    this.background,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: GlassTheme.glassDecoration(
        radius: radius,
        background: background,
      ),
      child: Padding(
        padding: padding ?? EdgeInsets.zero,
        child: child,
      ),
    );
  }
}
