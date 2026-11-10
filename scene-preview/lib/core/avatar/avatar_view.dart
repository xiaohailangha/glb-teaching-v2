import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_scene/scene.dart';

import '../../features/lesson/application/lesson_controller.dart';
import 'scene/scene_runtime.dart';
import 'scene/browser_graphics.dart';

class AvatarView extends StatefulWidget {
  const AvatarView({super.key, required this.controller, this.welcome = false});
  final bool welcome;
  final LessonController controller;
  @override
  State<AvatarView> createState() => _AvatarViewState();
}

class _AvatarViewState extends State<AvatarView>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late final SceneRuntime runtime;
  late final AnimationController welcome;
  late final BrowserGraphicsWatch graphics;
  bool _foreground = true, _graphicsLost = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    runtime = SceneRuntime(widget.controller);
    graphics = BrowserGraphicsWatch(() {
      if (!mounted || _graphicsLost) return;
      widget.controller.pauseCourse();
      unawaited(runtime.stop().catchError((Object _) {}));
      widget.controller.handle({'event': 'graphics-lost'});
      setState(() => _graphicsLost = true);
    });
    welcome = AnimationController(
      vsync: this,
      value: widget.welcome ? 1 : 0,
      duration: const Duration(milliseconds: 650),
    );
    void updateWelcome() {
      runtime.welcomeMix = welcome.value;
      runtime.background.welcomeMix = welcome.value;
    }

    welcome.addListener(updateWelcome);
    updateWelcome();
    Future.microtask(runtime.init);
  }

  @override
  void didUpdateWidget(AvatarView old) {
    super.didUpdateWidget(old);
    if (old.welcome != widget.welcome) {
      welcome.animateTo(widget.welcome ? 1 : 0, curve: Curves.easeInOutCubic);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    runtime.resetFrameSamples();
    if (mounted) {
      setState(() => _foreground = state == AppLifecycleState.resumed);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: runtime,
    builder: (context, _) => LayoutBuilder(
      builder: (context, size) {
        runtime.aspect = size.maxWidth / size.maxHeight;
        runtime.background.reduced = MediaQuery.disableAnimationsOf(context);
        if (!runtime.loaded || _graphicsLost) {
          return const SizedBox.expand();
        }
        return IgnorePointer(
          child: RepaintBoundary(
            child: SceneView(
              runtime.scene,
              onTick: runtime.tick,
              cameraBuilder: (_) => runtime.camera(),
              pixelRatio: 1,
              maxFrameRate: runtime.targetFps,
              autoTick: _foreground,
            ),
          ),
        );
      },
    ),
  );
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    welcome.dispose();
    graphics.dispose();
    runtime.dispose();
    super.dispose();
  }
}
