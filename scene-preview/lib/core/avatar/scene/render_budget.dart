import 'package:flutter/foundation.dart';

bool get isMobileBrowser =>
    kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android);

class RenderBudget {
  const RenderBudget({
    required this.fps,
    required this.scale,
    required this.minScale,
    required this.shadows,
  });
  final double fps, scale, minScale;
  final bool shadows;

  factory RenderBudget.resolve(String quality, {required bool mobileBrowser}) {
    if (mobileBrowser) {
      return switch (quality) {
        'low' => const RenderBudget(
          fps: 30,
          scale: .7,
          minScale: .65,
          shadows: false,
        ),
        'high' => const RenderBudget(
          fps: 60,
          scale: 1,
          minScale: .65,
          shadows: true,
        ),
        _ => const RenderBudget(
          fps: 60,
          scale: .85,
          minScale: .65,
          shadows: false,
        ),
      };
    }
    return RenderBudget(
      fps: {'high': 120.0, 'medium': 60.0, 'low': 30.0}[quality] ?? 60,
      scale: 1,
      minScale: .75,
      shadows: quality != 'low',
    );
  }
}
