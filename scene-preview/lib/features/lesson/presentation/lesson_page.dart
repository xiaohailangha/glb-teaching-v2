import 'package:flutter/material.dart';

import '../application/learning_sync.dart';

import '../../../core/avatar/avatar_view.dart';
import '../application/lesson_controller.dart';
import '../../settings/application/app_settings.dart';
import '../../settings/presentation/settings_panel.dart';
import 'adult_course_panel.dart';
import 'lesson_content_frame.dart';
import 'lesson_layout.dart';
import 'course_library_page.dart';
import '../application/curriculum_lesson_controller.dart';
import '../application/teaching_trial_controller.dart';
import '../domain/course_catalog.dart';
import '../../../core/avatar/scene/course_resources.dart';
import 'lesson_navigation.dart';
import 'landscape_classroom.dart';
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
  TeachingTrialController? trial;
  bool _resumeAfterRotate = false;
  void _portraitClassroom() {
    _resumeAfterRotate =
        teaching.adultCourse &&
        !teaching.coursePaused &&
        teaching.courseStep != 'summary';
    if (_resumeAfterRotate) teaching.pauseCourse();
  }

  void _landscapeClassroom() {
    if (!_resumeAfterRotate) return;
    _resumeAfterRotate = false;
    if (teaching.ready && teaching.coursePaused) teaching.playCourse();
  }

  LessonController get teaching => trial ?? pilot ?? controller;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    settings.addListener(_applySettings);
    settings.load();
    learningSync.start();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final state = await learningSync.api.request(
          'learning/curriculum/state?release=' +
              CourseResources.instance.release!,
        );
        final progress =
            (state['progress'] as List)
                .where((p) => courseCatalog.any((c) => c.id == p['course']))
                .toList()
              ..sort(
                (a, b) => (b['updated'] as int).compareTo(a['updated'] as int),
              );
        await _selectPilot(
          progress.isEmpty
              ? courseCatalog.first.id
              : progress.first['course'] as String,
        );
      } catch (error) {
        if (mounted)
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    });
  }

  void _applySettings() => controller.setRenderSettings(settings.command);
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && teaching.adultCourse) {
      teaching.pauseCourse();
    }
  }

  void _character() {
    if (!controller.ready || (pilot == null && trial == null)) return;
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
    trial?.pauseCourse();
    FormalDirectory? directory;
    if (widget.account != null) {
      try {
        final data = CourseResources.instance.catalog;
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
      teaching,
      directory: directory,
      onAdditionalSelected: _selectPilot,
      onTrialSelected: _selectTrial,
    );
  }

  Future<void> _selectPilot(String id) async {
    await trial?.flushProgress();
    await pilot?.flushProgress();
    CurriculumLessonController? next;
    if (!id.startsWith('N26-')) throw StateError('请选择正式课程');
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
    learningSync.curriculumCourse = id;
    final old = pilot;
    final oldTrial = trial;
    trial = null;
    setState(() => pilot = next);
    old?.dispose();
    oldTrial?.dispose();
    await WidgetsBinding.instance.endOfFrame;
  }

  Future<void> _selectTrial(String id) async {
    await pilot?.flushProgress();
    await trial?.flushProgress();
    final next = TeachingTrialController(
      api: learningSync.api,
      avatar: controller,
      id: id,
      onSelect: _selectTrial,
    );
    try {
      await next.initialize();
    } catch (_) {
      next.dispose();
      rethrow;
    }
    if (!mounted) {
      next.dispose();
      return;
    }
    final old = pilot, oldTrial = trial;
    learningSync.tick();
    learningSync.curriculumOverlay = true;
    learningSync.curriculumCourse = '';
    setState(() {
      pilot = null;
      trial = next;
    });
    old?.dispose();
    oldTrial?.dispose();
    await WidgetsBinding.instance.endOfFrame;
    // First speech starts from the existing character gesture, after its full load.
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
    trial?.dispose();
    if (widget.sharedController == null) controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LandscapeClassroom(
    onPortrait: _portraitClassroom,
    onLandscape: _landscapeClassroom,
    child: Listener(
      onPointerDown: (_) => learningSync.interact(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (controller.ready &&
                (pilot != null || trial != null) &&
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
              builder: (context, box) {
                final layout = LessonLayout(
                  box.biggest,
                  safe: MediaQuery.paddingOf(context),
                );
                final type = LessonType(layout.reading.size);
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    if (widget.sharedController == null)
                      Positioned.fill(
                        child: AvatarView(controller: controller),
                      ),
                    Positioned.fromRect(
                      rect: layout.avatar,
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
                      right: layout.margin,
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
                    Positioned.fromRect(
                      rect: layout.reading,
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        key: const ValueKey(
                                          'welcome-main-text',
                                        ),
                                        "${teaching.address('你好')}\n${teaching.activeCourse.title}",
                                        style: TextStyle(
                                          fontSize: type
                                              .main(teaching.activeCourse.title)
                                              .clamp(28, 72),
                                          height: 1.3,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      Text(
                                        teaching.ready
                                            ? '轻触任意位置，开始学习'
                                            : '人物正在准备…',
                                        style: TextStyle(
                                          color: Color(0xFFBDE5DD),
                                          fontSize: type.body,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        '首次允许麦克风，之后直接开口。\n练习语音用于在线识别与发音评测。',
                                        style: TextStyle(
                                          color: Colors.white60,
                                          fontSize: type.caption,
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
                      right: layout.margin,
                      bottom: 8,
                      child: SafeArea(
                        child: AnimatedBuilder(
                          animation: teaching,
                          builder: (context, _) =>
                              teaching.adultCourse &&
                                  (trial != null || !teaching.coursePaused)
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
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
}
