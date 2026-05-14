import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/glass_theme.dart';

/// Animated color blobs + grain overlay that floats behind all glass panels.
class AnimatedBackground extends StatefulWidget {
  const AnimatedBackground({super.key});

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground>
    with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(4, (i) {
      final duration = Duration(seconds: [28, 34, 40, 36][i]);
      return AnimationController(vsync: this, duration: duration)..repeat();
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Stack(
        children: [
          // Static base gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  GlassTheme.canvasGradientStart,
                  GlassTheme.canvas,
                  GlassTheme.canvasGradientEnd,
                ],
              ),
            ),
          ),
          // Animated blobs
          ..._buildBlobs(),
          // Grain overlay
          const _GrainOverlay(),
        ],
      ),
    );
  }

  List<Widget> _buildBlobs() {
    final blobConfigs = [
      _BlobConfig(
        color: GlassTheme.blobColors[0],
        size: 520,
        alignment: const Alignment(-1.2, -1.2),
        driftX: 60, driftY: 40,
        controllerIndex: 0,
      ),
      _BlobConfig(
        color: GlassTheme.blobColors[1],
        size: 460,
        alignment: const Alignment(1.3, -0.8),
        driftX: -50, driftY: 60,
        controllerIndex: 1,
      ),
      _BlobConfig(
        color: GlassTheme.blobColors[2],
        size: 600,
        alignment: const Alignment(0.0, 1.6),
        driftX: 40, driftY: -60,
        controllerIndex: 2,
      ),
      _BlobConfig(
        color: GlassTheme.blobColors[3],
        size: 380,
        alignment: const Alignment(0.5, 0.2),
        driftX: -30, driftY: 50,
        controllerIndex: 3,
      ),
    ];

    return blobConfigs.map((config) {
      return AnimatedBuilder(
        animation: _controllers[config.controllerIndex],
        builder: (context, _) {
          final t = _controllers[config.controllerIndex].value;
          final sinT = sin(t * 2 * pi);
          final dx = config.driftX * sinT;
          final dy = config.driftY * sinT;

          return Positioned.fill(
            child: Align(
              alignment: config.alignment,
              child: Transform.translate(
                offset: Offset(dx, dy),
                child: Container(
                  width: config.size,
                  height: config.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: config.color,
                    boxShadow: [
                      BoxShadow(
                        color: config.color.withValues(alpha: 0.5),
                        blurRadius: 80,
                        spreadRadius: 40,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    }).toList();
  }
}

class _BlobConfig {
  final Color color;
  final double size;
  final Alignment alignment;
  final double driftX;
  final double driftY;
  final int controllerIndex;

  const _BlobConfig({
    required this.color,
    required this.size,
    required this.alignment,
    required this.driftX,
    required this.driftY,
    required this.controllerIndex,
  });
}

/// Subtle noise grain overlay for texture.
class _GrainOverlay extends StatelessWidget {
  const _GrainOverlay();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Opacity(
          opacity: 0.03,
          child: CustomPaint(
            painter: _GrainPainter(),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }
}

class _GrainPainter extends CustomPainter {
  final _random = Random(42);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF000000);
    for (var i = 0; i < 2000; i++) {
      final x = _random.nextDouble() * size.width;
      final y = _random.nextDouble() * size.height;
      canvas.drawCircle(Offset(x, y), 0.5, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
