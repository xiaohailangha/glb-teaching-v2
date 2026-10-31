import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../lesson/application/lesson_controller.dart';

class WorldLoading extends StatefulWidget {
  const WorldLoading({
    super.key,
    required this.controller,
    required this.retry,
  });
  final LessonController controller;
  final VoidCallback retry;
  @override
  State<WorldLoading> createState() => _WorldLoadingState();
}

class _WorldLoadingState extends State<WorldLoading>
    with SingleTickerProviderStateMixin {
  late final motion = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  )..repeat();
  @override
  void dispose() {
    motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([widget.controller.resourceTick, motion]),
    builder: (context, _) {
      final c = widget.controller,
          portrait = MediaQuery.sizeOf(context).aspectRatio < 1;
      final reduced = MediaQuery.disableAnimationsOf(context);
      return ColoredBox(
        color: const Color(0xFF073645),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(painter: _AdventureSky(reduced ? 0 : motion.value)),
            SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: portrait ? 32 : 70,
                  vertical: 24,
                ),
                child: Column(
                  children: [
                    const Spacer(flex: 2),
                    const Text(
                      '一场开口说英语的小冒险',
                      style: TextStyle(
                        color: Color(0xFFE1F1E6),
                        fontSize: 15,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Stack(
                      children: [
                        Transform.translate(
                          offset: const Offset(0, 6),
                          child: Text(
                            'HELLO!',
                            style: TextStyle(
                              fontFamily: 'NotoSansIPA',
                              fontSize: portrait ? 72 : 100,
                              fontWeight: FontWeight.w900,
                              height: 1,
                              color: const Color(0xFF087176),
                              letterSpacing: -3,
                            ),
                          ),
                        ),
                        Text(
                          'HELLO!',
                          style: TextStyle(
                            fontFamily: 'NotoSansIPA',
                            fontSize: portrait ? 72 : 100,
                            fontWeight: FontWeight.w900,
                            height: 1,
                            color: const Color(0xFFFFE8A2),
                            letterSpacing: -3,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      '世界，从这一声开始',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(flex: 3),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 380),
                      child: Column(
                        children: [
                          if (c.error != null) ...[
                            const Text(
                              '这次准备没有完成',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              '检查网络后，我们再试一次。',
                              style: TextStyle(color: Colors.white70),
                            ),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: widget.retry,
                              child: const Text('重新准备'),
                            ),
                          ] else ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  c.resourceLabel,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  '${(c.resourceProgress * 100).floor()}%',
                                  style: const TextStyle(
                                    fontFamily: 'NotoSansIPA',
                                    color: Color(0xFFFFE8A2),
                                    fontSize: 18,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF052B39),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: LinearProgressIndicator(
                                  value: c.resourceProgress,
                                  minHeight: 12,
                                  backgroundColor: Colors.transparent,
                                  color: const Color(0xFFFFCF66),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              '人物和声音准备好，就可以出发',
                              style: TextStyle(
                                color: Color(0xFFB1D8D5),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _AdventureSky extends CustomPainter {
  _AdventureSky(this.t);
  final double t;
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height, p = Paint();
    canvas.drawRect(
      Offset.zero & size,
      p
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF06303E), Color(0xFF12636E), Color(0xFF40A49A)],
        ).createShader(Offset.zero & size),
    );
    p.shader = null;
    canvas.drawCircle(
      Offset(w * .17, h * .23),
      math.min(w, h) * .10,
      p..color = const Color(0xFFEFCA77),
    );
    for (var i = 0; i < 34; i++) {
      final x = ((i * .61803398875) % 1) * w, y = ((i * .371) % 1) * h * .65;
      canvas.drawCircle(
        Offset(x, y),
        i % 3 == 0 ? 1.7 : .8,
        p
          ..color = Colors.white.withValues(
            alpha: .15 + .2 * (.5 + .5 * math.sin(t * math.pi * 2 + i)),
          ),
      );
    }
    for (var i = 0; i < 3; i++) {
      final x = w * (.13 + i * .38) + math.sin(t * math.pi * 2 + i) * 12,
          y = h * (.16 + i * .16);
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, y), width: 100 + i * 35, height: 18),
        p..color = Colors.white.withValues(alpha: .06),
      );
    }
    for (var i = 0; i < 3; i++) {
      final y = h * (.68 + i * .10);
      final hill = Path()
        ..moveTo(0, y)
        ..cubicTo(w * .3, y - 80, w * .55, y + 100, w, y - 18)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close();
      canvas.drawPath(
        hill,
        p
          ..color = [
            const Color(0xFF246B70),
            const Color(0xFF15505B),
            const Color(0xFF0A3646),
          ][i],
      );
    }
    // A small paper plane travels through the world, not a fake loading animation.
    final x = w * .76, y = h * .52 + math.sin(t * math.pi * 2) * 10;
    canvas.drawPath(
      Path()
        ..moveTo(x - 42, y - 12)
        ..lineTo(x + 45, y - 35)
        ..lineTo(x + 10, y + 28)
        ..lineTo(x - 4, y + 4)
        ..close(),
      p..color = const Color(0xFFFFE8A2),
    );
    canvas.drawPath(
      Path()
        ..moveTo(x - 4, y + 4)
        ..lineTo(x + 45, y - 35)
        ..lineTo(x + 7, y + 11)
        ..close(),
      p..color = const Color(0xFFE3B95C),
    );
  }

  @override
  bool shouldRepaint(covariant _AdventureSky old) => old.t != t;
}
