import 'dart:math';
import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../providers/soul_provider.dart';

class SoulOrb extends StatefulWidget {
  final AppPhase phase;
  final double soundLevel;
  final double size;

  const SoulOrb({
    super.key,
    required this.phase,
    this.soundLevel = 0,
    this.size = 220,
  });

  @override
  State<SoulOrb> createState() => _SoulOrbState();
}

class _SoulOrbState extends State<SoulOrb>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _durationFor(widget.phase),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(SoulOrb old) {
    super.didUpdateWidget(old);
    if (old.phase != widget.phase) {
      _controller.duration = _durationFor(widget.phase);
      _controller.repeat(reverse: true);
    }
  }

  Duration _durationFor(AppPhase phase) {
    switch (phase) {
      case AppPhase.idle:
        return const Duration(milliseconds: 3200);
      case AppPhase.listening:
        return const Duration(milliseconds: 1800);
      case AppPhase.checkin:
      case AppPhase.speaking:
        return const Duration(milliseconds: 700);
      case AppPhase.nightlyReview:
        return const Duration(milliseconds: 2400);
    }
  }

  Color _colorFor(AppPhase phase) {
    switch (phase) {
      case AppPhase.idle:
        return AppColors.orbIdle;
      case AppPhase.listening:
        return AppColors.orbActive;
      case AppPhase.speaking:
      case AppPhase.checkin:
        return AppColors.orbSpeaking;
      case AppPhase.nightlyReview:
        return AppColors.orbListening;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(widget.phase);
    // Map sound level (-2 to 10) to extra scale 0..0.15
    final extra = ((widget.soundLevel + 2) / 12).clamp(0.0, 1.0) * 0.15;

    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) {
        final t = _pulse.value;
        final scale = 0.92 + t * 0.08 + extra;
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: _OrbPainter(
            color: color,
            scale: scale,
            pulseT: t,
            phase: widget.phase,
          ),
        );
      },
    );
  }
}

class _OrbPainter extends CustomPainter {
  final Color color;
  final double scale;
  final double pulseT;
  final AppPhase phase;

  _OrbPainter({
    required this.color,
    required this.scale,
    required this.pulseT,
    required this.phase,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) * scale;

    // Outer glow layers
    for (var i = 3; i >= 1; i--) {
      final glowRadius = radius * (1.0 + i * 0.22);
      final opacity = (0.06 / i) * (0.5 + pulseT * 0.5);
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            color.withOpacity(opacity),
            color.withOpacity(0),
          ],
        ).createShader(
          Rect.fromCircle(center: center, radius: glowRadius),
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
      canvas.drawCircle(center, glowRadius, paint);
    }

    // Mid ring
    final ringPaint = Paint()
      ..color = color.withOpacity(0.25 + pulseT * 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(center, radius * 1.18, ringPaint);

    // Inner orb with radial gradient
    final innerPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.4),
        colors: [
          Color.lerp(Colors.white, color, 0.4)!.withOpacity(0.9),
          color.withOpacity(0.95),
          color.withOpacity(0.6),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, innerPaint);

    // Specular highlight
    if (phase != AppPhase.idle) {
      final highlightPaint = Paint()
        ..color = Colors.white.withOpacity(0.25 + pulseT * 0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(
        Offset(center.dx - radius * 0.28, center.dy - radius * 0.32),
        radius * 0.22,
        highlightPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_OrbPainter old) =>
      old.scale != scale || old.pulseT != pulseT || old.color != color;
}
