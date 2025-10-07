import 'package:flutter/material.dart';

class HoverBubble extends StatefulWidget {
  const HoverBubble({super.key, required this.child, this.intensity = 1.0});
  final Widget child;
  final double intensity; // 0.5 .. 2.0

  @override
  State<HoverBubble> createState() => _HoverBubbleState();
}

class _HoverBubbleState extends State<HoverBubble> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _hovering = false;
  Offset _hoverPos = Offset.zero;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..addListener(() => setState(() {}))
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      onHover: (e) => setState(() => _hoverPos = e.localPosition),
      child: Stack(
        children: [
          widget.child,
          if (_hovering)
            IgnorePointer(
              child: CustomPaint(
                painter: _BubblePainter(
                  center: _hoverPos,
                  t: _controller.value,
                  intensity: widget.intensity,
                ),
                child: const SizedBox.expand(),
              ),
            ),
        ],
      ),
    );
  }
}

class _BubblePainter extends CustomPainter {
  _BubblePainter({required this.center, required this.t, required this.intensity});
  final Offset center;
  final double t; // 0..1
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint p = Paint()..blendMode = BlendMode.srcOver;
    final double base = 40 * intensity;
    final List<_Ring> rings = [
      _Ring(radius: base * (0.6 + 0.4 * t), color: const Color(0x332196F3)),
      _Ring(radius: base * (1.0 + 0.6 * t), color: const Color(0x221E88E5)),
      _Ring(radius: base * (1.6 + 0.8 * t), color: const Color(0x1A64B5F6)),
    ];
    for (final r in rings) {
      p.color = r.color;
      canvas.drawCircle(center, r.radius, p);
    }
  }

  @override
  bool shouldRepaint(covariant _BubblePainter oldDelegate) {
    return oldDelegate.center != center || oldDelegate.t != t || oldDelegate.intensity != intensity;
  }
}

class _Ring {
  const _Ring({required this.radius, required this.color});
  final double radius;
  final Color color;
}



