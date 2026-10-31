import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A clearly visible, non-interactive result. Only a scored pass shows it.
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
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: reduced
              ? Duration.zero
              : const Duration(milliseconds: 1800),
          builder: (context, t, _) => Stack(
            fit: StackFit.expand,
            children: [
              if (!reduced) CustomPaint(painter: CelebrationPainter(t)),
              Align(
                alignment: const Alignment(.65, -.03),
                child: FractionallySizedBox(
                  widthFactor: .34,
                  child: Opacity(
                    opacity: reduced ? 1 : (t * 7).clamp(0, 1),
                    child: Transform.scale(
                      scale: reduced
                          ? 1
                          : .82 +
                                .18 *
                                    Curves.easeOutBack.transform(
                                      (t * 4).clamp(0, 1),
                                    ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 24,
                          horizontal: 12,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xF02A514B), Color(0xF01B3339)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFBDE5DD)
                                  .withValues(alpha: .28),
                              blurRadius: 45,
                              spreadRadius: 5,
                            ),
                          ],
                          border: Border.all(
                            color: const Color(0xFFBDE5DD)
                                .withValues(alpha: .5),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CustomPaint(
                              size: Size(64, 64),
                              painter: CheckSealPainter(),
                            ),
                            const SizedBox(height: 12),
                            FittedBox(
                              child: Text(
                                message,
                                style: const TextStyle(
                                  fontFamily: 'NotoSansSC',
                                  color: Colors.white,
                                  fontSize: 30,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(height: 9),
                            const Text(
                              '很好，保持这个感觉',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'NotoSansSC',
                                color: Color(0xFFCCE7DE),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CheckSealPainter extends CustomPainter {
  const CheckSealPainter();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(
      size.center(Offset.zero),
      size.width / 2,
      Paint()..color = const Color(0xFFBDE5DD),
    );
    final path = Path()
      ..moveTo(size.width * .25, size.height * .51)
      ..lineTo(size.width * .43, size.height * .68)
      ..lineTo(size.width * .76, size.height * .33);
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF234C44)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(CheckSealPainter old) => false;
}

class CelebrationPainter extends CustomPainter {
  const CelebrationPainter(this.t);
  final double t;
  @override
  void paint(Canvas canvas, Size size) {
    const colors = [
      Color(0xFFFFD587),
      Color(0xFFBDE5DD),
      Color(0xFFFFF5DA),
      Color(0xFF8BDCD6),
    ];
    for (var burst = 0; burst < 2; burst++) {
      final progress = ((t - burst * .14) / .85).clamp(0.0, 1.0);
      if (progress <= 0) continue;
      final origin = Offset(
        size.width * (burst == 0 ? .64 : .90),
        size.height * (burst == 0 ? .38 : .54),
      );
      final fade = (1 - progress).clamp(0.0, 1.0);
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = colors[burst].withValues(alpha: fade * .65);
      canvas.drawCircle(origin, progress * size.shortestSide * .37, ring);
      for (var i = 0; i < 40; i++) {
        final angle = i * 2.399963 + burst, speed = 75 + (i % 7) * 19.0;
        final distance = speed * Curves.easeOutCubic.transform(progress);
        final p =
            origin +
            Offset(
              math.cos(angle) * distance,
              math.sin(angle) * distance + progress * progress * 45,
            );
        final paint = Paint()
          ..color = colors[i % colors.length].withValues(alpha: fade)
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round;
        canvas.save();
        canvas.translate(p.dx, p.dy);
        canvas.rotate(angle + progress * 5);
        if (i % 3 == 0) {
          canvas.drawCircle(Offset.zero, 2.5, paint);
        } else {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              const Rect.fromLTWH(-2, -5, 4, 10),
              const Radius.circular(1),
            ),
            paint,
          );
        }
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(CelebrationPainter old) => old.t != t;
}
