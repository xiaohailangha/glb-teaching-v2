import 'package:flutter/material.dart';
import 'package:flutter_scene/scene.dart';

import '../../features/lesson/application/lesson_controller.dart';
import 'scene/scene_runtime.dart';

class AvatarView extends StatefulWidget {
  const AvatarView({super.key, required this.controller});
  final LessonController controller;
  @override
  State<AvatarView> createState() => _AvatarViewState();
}

class _AvatarViewState extends State<AvatarView> with WidgetsBindingObserver {
  late final SceneRuntime runtime;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    runtime = SceneRuntime(widget.controller);
    runtime.init();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    runtime.resetFrameSamples();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: runtime,
    builder: (context, _) => LayoutBuilder(
      builder: (context, size) {
        runtime.aspect = size.maxWidth / size.maxHeight;
        runtime.background.reduced = MediaQuery.disableAnimationsOf(context);
        if (!runtime.loaded) {
          return Center(
            child: Text(
              runtime.loading,
              style: const TextStyle(color: Colors.white70),
            ),
          );
        }
        return IgnorePointer(
          child: SceneView(
            runtime.scene,
            onTick: runtime.tick,
            cameraBuilder: (_) => runtime.camera(),
            pixelRatio: 1,
            maxFrameRate: runtime.targetFps,
          ),
        );
      },
    ),
  );
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    runtime.dispose();
    super.dispose();
  }
}
