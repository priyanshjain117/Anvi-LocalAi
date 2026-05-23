import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/anvi_colors.dart';

class GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadiusGeometry borderRadius;
  final Color? color;
  final bool glow;

  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
    this.color,
    this.glow = false,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: padding,
          decoration: BoxDecoration(
            color: color ?? Colors.white.withValues(alpha: 0.055),
            borderRadius: borderRadius,
            border: Border.all(color: AnviColors.line),
            boxShadow: glow
                ? [
                    BoxShadow(
                      color: AnviColors.ember.withValues(alpha: 0.18),
                      blurRadius: 28,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: child,
        ),
      ),
    );
  }
}
