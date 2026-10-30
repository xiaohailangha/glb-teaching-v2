# Local changes to flutter_scene 0.24.3

Upstream: https://github.com/bdero/flutter_scene ; package obtained from pub.dev. The upstream MIT license is retained.

- `pubspec.yaml`: removed workspace resolution for a standalone path dependency.
- `lib/src/geometry/morph_targets.dart`: active GPU targets 8 → 64; maximum morph texture dimension 2048 → 4096; direct half-float payload packing without a full-sized float32 staging allocation.
- `lib/src/geometry/morphed_geometry.dart`: upload morph position/normal deltas as RGBA16F instead of RGBA32F.
- `shaders/flutter_scene_morph.glsl`: uniform array capacity matches the Dart budget of 64.
- `shaders/impeller/`: SDK shader include headers from Flutter 3.47.9, with their BSD license. This gives Windows impellerc an ASCII include path through the project's temporary V: mapping when the actual workspace contains Chinese characters.

The app tests cover retention of all 52 Storm morph channels, the head texture budget, and half-float packing. These are compatibility changes, not a phone performance claim. Compare future upstream releases before rebasing this local copy.
