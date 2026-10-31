import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Transparent fireworks over the lesson. No card, scrim, badge or visible text.
class CourseCelebration extends StatelessWidget {
  const CourseCelebration({super.key, required this.message});
  final String message;
  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return IgnorePointer(
      child: Semantics(
        liveRegion: true,
        label: message,
        child: RepaintBoundary(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: reduced
                ? Duration.zero
                : const Duration(milliseconds: 1800),
            builder: (context, t, _) => CustomPaint(
              painter: CelebrationPainter(t, reduced: reduced),
              size: Size.infinite,
            ),
          ),
        ),
      ),
    );
  }
}

class CelebrationPainter extends CustomPainter {
  const CelebrationPainter(this.t, {this.reduced = false});
  final double t;
  final bool reduced;
  static const colors = [
    Color(0xFFFFDB9E),
    Color(0xFFC5EEE5),
    Color(0xFFD9DEFF),
  ];

  void light(
    Canvas canvas,
    Offset p,
    Color color,
    double alpha,
    double radius,
  ) {
    if (alpha <= 0) return;
    final paint = Paint()..color = color.withValues(alpha: alpha * .07);
    canvas.drawCircle(p, radius * 4.5, paint);
    paint.color = color.withValues(alpha: alpha * .20);
    canvas.drawCircle(p, radius * 2.2, paint);
    paint.color = color.withValues(alpha: alpha * .80);
    canvas.drawCircle(p, radius, paint);
    paint.color = const Color(0xFFFFFCF0).withValues(alpha: alpha);
    canvas.drawCircle(p, radius * .38, paint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    if (reduced) {
      // A few stationary highlights; no replacement popup for reduced motion.
      for (var i = 0; i < 7; i++) {
        light(
          canvas,
          Offset(size.width * (.61 + i * .045), size.height * .23),
          colors[i % 3],
          .6,
          1.7,
        );
      }
      return;
    }
    if (t <= 0 || t >= 1) return;
    final unit = math.min(size.height, size.width * .55);
    canvas.save();
    canvas.clipRect(
      Rect.fromLTWH(size.width * .48, 0, size.width * .52, size.height * .87),
    );
    for (var burst = 0; burst < 3; burst++) {
      final start = .055 + burst * .115;
      final age = (t - start) / (.84 - burst * .115);
      final origin = Offset(
        size.width * [.64, .88, .77][burst],
        size.height * [.30, .44, .20][burst],
      );
      final color = colors[burst];
      if (age < 0 && age > -.09) {
        final launch = (age + .09) / .09;
        final head =
            origin + Offset(-8 * (1 - launch), unit * .22 * (1 - launch));
        canvas.drawLine(
          head,
          head + Offset(-2, 24 * launch),
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [color.withValues(alpha: .8), color.withValues(alpha: 0)],
            ).createShader(Rect.fromLTWH(head.dx - 2, head.dy, 4, 25))
            ..strokeWidth = 1.3
            ..strokeCap = StrokeCap.round,
        );
        light(canvas, head, color, launch * .8, 1.4);
        continue;
      }
      if (age <= 0 || age >= 1) continue;
      final count = [76, 64, 56][burst];
      final radius = unit * [.30, .25, .20][burst];
      final fade = math.pow(1 - age, .9).toDouble();
      // Short luminous core, then multiple uneven, curved trails and tiny embers.
      light(canvas, origin, color, math.pow(1 - age, 8).toDouble(), 5);
      for (var i = 0; i < count; i++) {
        final angle = i * math.pi * 2 / count + burst * .47;
        final hash = math.sin(i * 12.9898 + burst * 78.233) * 43758.5453;
        final variation = .48 + .52 * (hash - hash.floor());
        final speed = radius * variation;
        Offset point(double a) {
          final travel = 1 - math.exp(-3.8 * a);
          return origin +
              Offset(
                math.cos(angle) * speed * travel,
                math.sin(angle) * speed * travel * .85 + unit * .15 * a * a,
              );
        }

        final p = point(age);
        for (var segment = 0; segment < 5; segment++) {
          final tailAge = math.max(0.0, age - (segment + 1) * .04);
          final tipAge = math.max(0.0, age - segment * .04);
          canvas.drawLine(
            point(tailAge),
            point(tipAge),
            Paint()
              ..color = color.withValues(alpha: fade * (1 - segment / 5) * .63)
              ..strokeWidth = (i % 4 == 0 ? 1.25 : .7) * (1 - segment * .11)
              ..strokeCap = StrokeCap.round,
          );
        }
        final shimmer = .72 + .28 * math.sin(age * 32 + i * 2.4);
        light(canvas, p, color, fade * shimmer, i % 7 == 0 ? 1.9 : 1.05);
        if (i % 4 == 0 && age > .25) {
          final ember = (age - .25) / .75;
          final offset = Offset(
            math.sin(i * 8.1) * unit * .035 * ember,
            unit * .055 * ember,
          );
          light(canvas, p + offset, color, fade * (1 - ember) * .65, .75);
        }
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(CelebrationPainter old) =>
      old.t != t || old.reduced != reduced;
}
