import 'package:flutter/material.dart';

import '../application/learning_sync.dart';

import '../../../core/avatar/avatar_view.dart';
import '../application/lesson_controller.dart';
import '../../settings/application/app_settings.dart';
import '../../settings/presentation/settings_panel.dart';
import 'adult_course_panel.dart';
import 'lesson_content_frame.dart';
import 'course_library_page.dart';
import '../application/curriculum_lesson_controller.dart';
import '../domain/course_catalog.dart';
import 'lesson_navigation.dart';
import '../../auth/auth_api.dart';

class LessonPage extends StatefulWidget {
  const LessonPage({
    super.key,
    this.account,
    this.auth,
    this.onLeave,
    this.sharedController,
  });
  final LessonController? sharedController;
  final LearnerAccount? account;
  final AuthApi? auth;
  final Future<void> Function()? onLeave;
  @override
  State<LessonPage> createState() => _LessonPageState();
}

class _LessonPageState extends State<LessonPage> with WidgetsBindingObserver {
  late final controller =
      widget.sharedController ??
      LessonController(
        accountId: widget.account?.id ?? '',
        accountNickname: widget.account?.nickname,
        saveAccountNickname: widget.account == null
            ? null
            : widget.auth?.rename,
      );
  final settings = AppSettings();
  late final learningSync = LearningSync(controller);
  CurriculumLessonController? pilot;
  LessonController get teaching => pilot ?? controller;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    settings.addListener(_applySettings);
    settings.load();
    learningSync.start();
    if (widget.sharedController == null) controller.loadCourseProgress();
  }

  void _applySettings() => controller.setRenderSettings(settings.command);
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && teaching.adultCourse) {
      teaching.pauseCourse();
    }
  }

  void _character() {
    if (!controller.ready) return;
    if (teaching.adultCourse &&
        !teaching.coursePaused &&
        teaching.courseStep != 'summary') {
      teaching.replayLesson();
    } else {
      teaching.playCourse(restart: teaching.courseStep == 'summary');
    }
  }

  Future<void> _courses() async {
    if (controller.adultCourse && !controller.coursePaused) {
      controller.pauseCourse();
    }
    pilot?.pauseCourse();
    FormalDirectory? directory;
    if (widget.account != null) {
      try {
        final data = await learningSync.api.request('learning/curriculum');
        directory = FormalDirectory(data);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('新增课程暂时未能加载，请稍后再试')));
        }
      }
    }
    if (!mounted) return;
    await showCourseLibrary(
      context,
      controller,
      directory: directory,
      onAdditionalSelected: _selectPilot,
    );
  }

  Future<void> _selectPilot(String id) async {
    CurriculumLessonController? next;
    if (id.isNotEmpty) {
      next = CurriculumLessonController(
        api: learningSync.api,
        avatar: controller,
        id: id,
        onSelect: _selectPilot,
      );
      try {
        await next.initialize();
      } catch (_) {
        next.dispose();
        rethrow;
      }
    }
    if (!mounted) {
      next?.dispose();
      return;
    }
    learningSync.tick();
    learningSync.curriculumOverlay = id.isNotEmpty;
    final old = pilot;
    setState(() => pilot = next);
    old?.dispose();
    await WidgetsBinding.instance.endOfFrame;
  }

  Future<void> _settings() async {
    final current = teaching;
    final resume =
        current.adultCourse &&
        !current.coursePaused &&
        current.courseStep != 'summary';
    final courseId = current.courseId;
    if (current.adultCourse && !current.coursePaused) {
      current.pauseCourse();
    }
    final leaving = await showLearningSettings(
      context,
      settings: settings,
      lesson: controller,
      account: widget.account,
      onLeave: widget.onLeave,
      loadSummary: () async {
        learningSync.tick();
        await learningSync.flush();
        return learningSync.api.request('learning/summary');
      },
    );
    if (mounted &&
        leaving != true &&
        resume &&
        current.courseId == courseId &&
        current.coursePaused &&
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      current.playCourse();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    settings.removeListener(_applySettings);
    settings.dispose();
    learningSync.dispose();
    pilot?.dispose();
    if (widget.sharedController == null) controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (_) => learningSync.interact(),
    child: Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (controller.ready &&
              (!teaching.adultCourse || teaching.coursePaused)) {
            teaching.playCourse();
          }
        },
        child: DecoratedBox(
          decoration: widget.sharedController != null
              ? const BoxDecoration()
              : const BoxDecoration(
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
                if (widget.sharedController == null)
                  Positioned.fill(child: AvatarView(controller: controller)),
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: box.maxWidth * .44,
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
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: '课程',
                          onPressed: _courses,
                          icon: const Icon(
                            Icons.auto_stories_outlined,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: '我的',
                          onPressed: _settings,
                          icon: const Icon(
                            Icons.person_outline_rounded,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: box.maxWidth * .45,
                  right: box.maxWidth * .04,
                  top: box.maxHeight * .10,
                  bottom: 62,
                  child: AnimatedBuilder(
                    animation: teaching,
                    builder: (context, _) => AnimatedSwitcher(
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 320),
                      layoutBuilder: (current, previous) => Stack(
                        fit: StackFit.expand,
                        children: [
                          for (final child in previous)
                            IgnorePointer(
                              child: ExcludeSemantics(child: child),
                            ),
                          ?current,
                        ],
                      ),
                      child: teaching.adultCourse
                          ? AdultCoursePanel(
                              key: const ValueKey('active-lesson'),
                              controller: teaching,
                            )
                          : LessonContentFrame(
                              key: const ValueKey('welcome-lesson'),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    key: const ValueKey('welcome-main-text'),
                                    "${teaching.address('你好')}\n${teaching.activeCourse.goal}",
                                    style: const TextStyle(
                                      fontSize: 36,
                                      height: 1.3,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Text(
                                    teaching.ready ? '轻触任意位置，开始学习' : '人物正在准备…',
                                    style: const TextStyle(
                                      color: Color(0xFFBDE5DD),
                                      fontSize: 18,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  const Text(
                                    '首次允许麦克风，之后直接开口。\n练习语音用于在线识别与发音评测。',
                                    style: TextStyle(
                                      color: Colors.white60,
                                      fontSize: 14,
                                      height: 1.6,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ),
                ),
                Positioned(
                  right: 20,
                  bottom: 8,
                  child: SafeArea(
                    child: AnimatedBuilder(
                      animation: teaching,
                      builder: (context, _) =>
                          teaching.adultCourse && !teaching.coursePaused
                          ? LessonNavigation(controller: teaching)
                          : const SizedBox.shrink(),
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
      ),
    ),
  );
}
