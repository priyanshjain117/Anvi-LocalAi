import 'package:flutter/material.dart';

import '../theme/anvi_colors.dart';

class AnviLogo extends StatelessWidget {
  final double size;
  final bool pulse;

  const AnviLogo({
    super.key,
    this.size = 44,
    this.pulse = false,
  });

  @override
  Widget build(BuildContext context) {
    final logo = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const SweepGradient(
          colors: [
            AnviColors.crimson,
            AnviColors.ember,
            AnviColors.champagne,
            AnviColors.crimson,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AnviColors.ember.withValues(alpha: 0.45),
            blurRadius: size * 0.55,
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: size * 0.68,
          height: size * 0.68,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AnviColors.voidBlack,
          ),
          child: Center(
            child: Text(
              'A',
              style: TextStyle(
                color: AnviColors.champagne,
                fontSize: size * 0.34,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );

    if (!pulse) return logo;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.94, end: 1.06),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeInOut,
      builder: (context, value, child) =>
          Transform.scale(scale: value, child: child),
      onEnd: () {},
      child: logo,
    );
  }
}
