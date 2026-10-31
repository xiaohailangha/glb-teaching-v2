import 'package:flutter_scene/scene.dart';

import 'dart:typed_data';
import 'dart:math' as math;

import '../../../features/lesson/domain/firework_pattern.dart';

/// Keep text in Flutter's foreground while composing the character's edge
/// coverage onto the same page gradient entirely on the GPU.
class TeachingBackground extends CustomRenderPass {
  double time = -1, started = -100;
  bool reduced = false;
  double welcomeMix = 0;
  FireworkPattern? pattern;
  void celebrate(double now) {
    started = now;
    pattern = FireworkPattern.generate(math.Random().nextInt(1 << 30));
  }

  void cancel() {
    started = -100;
    pattern = null;
  }

  @override
  String get name => 'Teaching page background';
  @override
  RenderStage get stage => RenderStage.afterToneMapping;
  @override
  void execute(RenderPassContext context) {
    final data = Float32List(48);
    final progress = (time - started) / 1.8;
    final active = pattern != null && progress >= 0 && progress < 1;
    data[0] = active ? progress : -1;
    data[1] = active ? pattern!.bursts.length.toDouble() : 0;
    data[2] = context.dimensions.width / context.dimensions.height;
    data[3] = reduced ? 1 : 0;
    data[44] = welcomeMix;
    if (active) {
      for (var i = 0; i < pattern!.bursts.length; i++) {
        final b = pattern!.bursts[i];
        data.setRange(4 + i * 4, 8 + i * 4, [
          b.center.dx,
          b.center.dy,
          b.start,
          b.end,
        ]);
        data.setRange(24 + i * 4, 28 + i * 4, [
          b.radius,
          b.rays.toDouble(),
          b.color.toDouble(),
          b.seed,
        ]);
      }
    }
    context.applyShader(
      baseShaderLibrary['TeachingBackgroundFragment']!,
      uniforms: {'FireworksInfo': ByteData.sublistView(data)},
    );
  }
}
