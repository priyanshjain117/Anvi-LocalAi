import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/anvi_colors.dart';

class AmbientBackground extends StatefulWidget {
  final Widget child;
  final bool particles;

  const AmbientBackground({
    super.key,
    required this.child,
    this.particles = true,
  });

  @override
  State<AmbientBackground> createState() => _AmbientBackgroundState();
}

class _AmbientBackgroundState extends State<AmbientBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _AmbientPainter(
            progress: _controller.value,
            drawParticles: widget.particles,
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _AmbientPainter extends CustomPainter {
  final double progress;
  final bool drawParticles;

  const _AmbientPainter({
    required this.progress,
    required this.drawParticles,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final base = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AnviColors.voidBlack,
          AnviColors.obsidian,
          Color(0xFF160B06),
          AnviColors.voidBlack,
        ],
      ).createShader(rect);
    canvas.drawRect(rect, base);

    final glowPaint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 48);
    final t = progress * math.pi * 2;
    final glowA = Offset(
      size.width * (0.72 + math.sin(t) * 0.08),
      size.height * (0.18 + math.cos(t * 0.7) * 0.05),
    );
    final glowB = Offset(
      size.width * (0.18 + math.cos(t * 0.8) * 0.05),
      size.height * (0.82 + math.sin(t * 0.6) * 0.06),
    );

    glowPaint.color = AnviColors.ember.withValues(alpha: 0.22);
    canvas.drawCircle(glowA, size.shortestSide * 0.34, glowPaint);
    glowPaint.color = AnviColors.crimson.withValues(alpha: 0.13);
    canvas.drawCircle(glowB, size.shortestSide * 0.26, glowPaint);
    glowPaint.color = AnviColors.champagne.withValues(alpha: 0.08);
    canvas.drawCircle(
        size.center(Offset.zero), size.shortestSide * 0.42, glowPaint);

    if (!drawParticles) return;
    final particlePaint = Paint()
      ..color = AnviColors.champagne.withValues(alpha: 0.14);
    for (var i = 0; i < 42; i++) {
      final seed = i * 19.37;
      final x = (math.sin(seed + t * 0.24) * 0.5 + 0.5) * size.width;
      final y = ((seed * 37 + progress * 120) % size.height);
      final radius = 0.7 + (i % 3) * 0.35;
      canvas.drawCircle(Offset(x, y), radius, particlePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _AmbientPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.drawParticles != drawParticles;
  }
}
