import 'package:flutter_scene/scene.dart';

/// Keep text in Flutter's foreground while composing the character's edge
/// coverage onto the same page gradient entirely on the GPU.
class TeachingBackground extends CustomRenderPass {
  @override
  String get name => 'Teaching page background';
  @override
  RenderStage get stage => RenderStage.afterToneMapping;
  @override
  void execute(RenderPassContext context) {
    context.applyShader(baseShaderLibrary['TeachingBackgroundFragment']!);
  }
}
