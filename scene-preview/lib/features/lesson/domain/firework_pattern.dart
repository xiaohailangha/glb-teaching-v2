import 'dart:math' as math;
import 'dart:ui';

class FireworkBurst {
  const FireworkBurst({
    required this.center,
    required this.start,
    required this.end,
    required this.radius,
    required this.rays,
    required this.color,
    required this.rotation,
    required this.gravity,
    required this.aspect,
    required this.seed,
  });
  final Offset center;
  final double start, end, radius, rotation, gravity, aspect, seed;
  final int rays, color;
}

class FireworkPattern {
  const FireworkPattern(this.bursts);
  final List<FireworkBurst> bursts;
  factory FireworkPattern.generate(int seed) {
    final random = math.Random(seed), count = 4 + math.Random(seed).nextInt(2);
    // Stratified horizontal zones guarantee both sides, then randomize firing order.
    final zones = List.generate(count, (i) => i)..shuffle(random);
    return FireworkPattern(
      List.unmodifiable(
        List.generate(count, (i) {
          final x =
              .10 + .80 * (zones[i] + .2 + random.nextDouble() * .6) / count;
          final y = .18 + random.nextDouble() * .52;
          final start = .035 + i * .055 + random.nextDouble() * .035;
          return FireworkBurst(
            center: Offset(x, y),
            start: start,
            end: .86 + random.nextDouble() * .11,
            radius: .19 + random.nextDouble() * .095,
            rays: 44 + random.nextInt(17),
            color: random.nextInt(4),
            rotation: random.nextDouble() * math.pi * 2,
            gravity: .08 + random.nextDouble() * .09,
            aspect: .74 + random.nextDouble() * .22,
            seed: random.nextDouble() * 1000,
          );
        }),
      ),
    );
  }
}
