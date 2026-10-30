import 'package:flutter/material.dart';

import '../../../core/avatar/avatar_view.dart';
import '../application/lesson_controller.dart';
import '../../settings/application/app_settings.dart';
import '../../settings/presentation/settings_panel.dart';
import 'adult_course_panel.dart';

class LessonPage extends StatefulWidget {
  const LessonPage({super.key});
  @override
  State<LessonPage> createState() => _LessonPageState();
}

class _LessonPageState extends State<LessonPage> with WidgetsBindingObserver {
  final controller = LessonController();
  final settings = AppSettings();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    settings.addListener(_applySettings);
    settings.load();
    controller.loadCourseProgress();
  }

  void _applySettings() => controller.setRenderSettings(settings.command);
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && controller.adultCourse) {
      controller.pauseCourse();
    }
  }

  void _character() {
    if (!controller.ready) return;
    if (controller.adultCourse &&
        !controller.coursePaused &&
        controller.courseStep != 'summary') {
      controller.replayLesson();
    } else {
      controller.playCourse(restart: controller.courseStep == 'summary');
    }
  }

  void _settings() {
    if (controller.adultCourse && !controller.coursePaused) {
      controller.pauseCourse();
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: const Color(0xFF303236),
      constraints: BoxConstraints(
        maxWidth: 520,
        maxHeight: MediaQuery.sizeOf(context).height * .86,
      ),
      builder: (_) => SettingsPanel(settings: settings, lesson: controller),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    settings.removeListener(_applySettings);
    settings.dispose();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF34393D), Color(0xFF777E80)],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, box) => Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(child: AvatarView(controller: controller)),
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: box.maxWidth * .59,
              child: Semantics(
                button: true,
                label: '点击人物，开始或重听示范',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _character,
                ),
              ),
            ),
            Positioned(
              top: 12,
              right: 18,
              child: SafeArea(
                child: IconButton(
                  tooltip: '设置',
                  onPressed: _settings,
                  icon: const Icon(Icons.tune_rounded, color: Colors.white70),
                ),
              ),
            ),
            Positioned(
              left: box.maxWidth * .60,
              right: box.maxWidth * .06,
              top: box.maxHeight * .10,
              bottom: box.maxHeight * .06,
              child: AnimatedBuilder(
                animation: controller,
                builder: (context, _) => controller.adultCourse
                    ? AdultCoursePanel(controller: controller)
                    : Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '从一个苹果\n开始说英语',
                              style: TextStyle(
                                fontSize: 30,
                                height: 1.3,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              controller.ready ? '轻触人物，开始学习' : '人物正在准备…',
                              style: const TextStyle(
                                color: Color(0xFFBDE5DD),
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              '首次允许麦克风，之后直接开口。\n练习语音用于在线识别与发音评测。',
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 12,
                                height: 1.6,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
            AnimatedBuilder(
              animation: controller,
              builder: (context, _) => controller.error == null
                  ? const SizedBox.shrink()
                  : Center(
                      child: Text(
                        controller.error!,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
            ),
          ],
        ),
      ),
    ),
  );
}
