import 'dart:math';
import 'package:flutter/material.dart';
import '../core/constants.dart';

class WaveformWidget extends StatefulWidget {
  final double soundLevel; // -2 to 10 (from speech_to_text)
  final Color color;
  final int barCount;
  final double height;

  const WaveformWidget({
    super.key,
    required this.soundLevel,
    this.color = AppColors.amber,
    this.barCount = 5,
    this.height = 48,
  });

  @override
  State<WaveformWidget> createState() => _WaveformWidgetState();
}

class _WaveformWidgetState extends State<WaveformWidget>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.barCount, (i) {
      final ctrl = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 400 + i * 80),
      )..repeat(reverse: true);
      return ctrl;
    });

    _animations = _controllers.map((ctrl) {
      return Tween<double>(begin: 0.1, end: 1.0).animate(
        CurvedAnimation(parent: ctrl, curve: Curves.easeInOut),
      );
    }).toList();
  }

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final amplitude = ((widget.soundLevel + 2) / 12).clamp(0.0, 1.0);

    return SizedBox(
      height: widget.height,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(widget.barCount, (i) {
          return AnimatedBuilder(
            animation: _animations[i],
            builder: (_, __) {
              final barHeight = widget.height *
                  (0.15 + _animations[i].value * 0.85 * amplitude +
                      0.1 * sin(i * 1.2));
              return Container(
                width: 4,
                height: barHeight.clamp(4.0, widget.height),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: widget.color
                      .withOpacity(0.5 + amplitude * 0.5),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}
