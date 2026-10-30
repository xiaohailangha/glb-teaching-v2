import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/avatar/avatar_view.dart';
import '../application/lesson_controller.dart';
import '../domain/lesson_word.dart';
import '../domain/emotion.dart';
import '../domain/phonetic_token.dart';
import '../../settings/application/app_settings.dart';
import '../../settings/presentation/settings_panel.dart';

class LessonPage extends StatefulWidget {
  const LessonPage({super.key});
  @override
  State<LessonPage> createState() => _LessonPageState();
}

class _LessonPageState extends State<LessonPage> {
  final controller = LessonController();
  final settings = AppSettings();
  @override
  void initState() {
    super.initState();
    settings.addListener(_applySettings);
    settings.load();
  }

  void _applySettings() => controller.setRenderSettings(settings.command);
  void _showSettings() {
    _hideControls();
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

  Timer? _hideTimer;
  bool _controlsVisible = false;

  void _showControls() {
    _hideTimer?.cancel();
    if (!_controlsVisible) setState(() => _controlsVisible = true);
    _hideTimer = Timer(const Duration(seconds: 5), _hideControls);
  }

  void _hideControls() {
    _hideTimer?.cancel();
    Tooltip.dismissAllToolTips();
    if (mounted) setState(() => _controlsVisible = false);
  }

  void _play() {
    if (controller.courseMode && controller.playing) return;
    if (controller.emotionMode) {
      controller.togglePlayback();
    } else {
      controller.play();
    }
    _hideControls();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    settings.removeListener(_applySettings);
    settings.dispose();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      const SingleActivator(LogicalKeyboardKey.space):
          controller.togglePlayback,
      const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
          controller.step(1),
      const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
          controller.step(-1),
      const SingleActivator(LogicalKeyboardKey.escape): () {
        _hideControls();
      },
    },
    child: Focus(
      autofocus: true,
      child: Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF444444), Color(0xFF7D7D7D), Color(0xFF808080)],
              stops: [0, .72, 1],
            ),
          ),
          child: LayoutBuilder(
            builder: (context, box) {
              final wide = box.maxWidth > box.maxHeight;
              return GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _showControls,
                onHorizontalDragEnd: (details) {
                  final speed = details.primaryVelocity ?? 0;
                  if (speed.abs() > 100) controller.step(speed < 0 ? 1 : -1);
                },
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Positioned.fill(child: AvatarView(controller: controller)),
                    Positioned(
                      top: 12,
                      right: 18,
                      child: SafeArea(
                        child: IconButton(
                          tooltip: '设置',
                          onPressed: _showSettings,
                          icon: const Icon(
                            Icons.settings_outlined,
                            color: Colors.white60,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: box.maxWidth * .075,
                      bottom: box.maxHeight * .08,
                      child: AnimatedBuilder(
                        animation: controller,
                        builder: (context, _) => TextButton.icon(
                          onPressed: controller.ready ? _showDemos : null,
                          icon: const Icon(Icons.grid_view_rounded, size: 16),
                          label: const Text('演示库'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white54,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: box.maxWidth * .60,
                      right: box.maxWidth * .075,
                      top: box.maxHeight * .07,
                      bottom: 0,
                      child: Center(
                        child: AnimatedBuilder(
                          animation: controller,
                          builder: (context, _) => Semantics(
                            button: true,
                            label: controller.emotionMode
                                ? '重播${controller.emotion.label}'
                                : controller.hideAnswer
                                ? '回忆练习'
                                : '听示范 ${controller.word.id}',
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                controller.playWord();
                                _hideControls();
                              },
                              child: SizedBox(
                                width: double.infinity,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (!controller.emotionMode &&
                                        !controller.hideAnswer)
                                      _pronunciationLine(wide)
                                    else if (controller.emotionMode)
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          controller.emotionMode
                                              ? 'EMOTION STUDIES'
                                              : controller.lessonHeading,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: box.maxWidth * .036,
                                            fontVariations: const [
                                              FontVariation('wght', 350),
                                            ],
                                            height: 1.25,
                                          ),
                                        ),
                                      ),
                                    SizedBox(height: box.maxHeight * .008),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child:
                                          controller.courseMode &&
                                              controller.courseStyle.startsWith(
                                                'child',
                                              ) &&
                                              controller.lessonPhase == 'recall'
                                          ? Semantics(
                                              label: '苹果图片',
                                              child: const CustomPaint(
                                                size: Size(110, 100),
                                                painter: _FruitPainter('apple'),
                                              ),
                                            )
                                          : Text(
                                              controller.emotionMode
                                                  ? controller.emotion.english
                                                  : controller.displayWord,
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: box.maxWidth * .084,
                                                fontWeight: FontWeight.w900,
                                                fontVariations: const [
                                                  FontVariation('wght', 900),
                                                ],
                                                height: 1.12,
                                                letterSpacing: -.8,
                                              ),
                                            ),
                                    ),
                                    if (!controller.emotionMode) ...[
                                      const SizedBox(height: 14),
                                      Text(
                                        controller.lessonHint,
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: wide ? 16 : 12,
                                          height: 1.5,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      if (controller.speechFeedback.isNotEmpty)
                                        Text(
                                          controller.speechFeedback,
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 14,
                                          ),
                                        ),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 2,
                                        children: [
                                          if (controller.canCapture)
                                            TextButton.icon(
                                              onPressed:
                                                  controller.processingSpeech ||
                                                      controller.captureState ==
                                                          'starting'
                                                  ? null
                                                  : controller.toggleCapture,
                                              icon: Icon(
                                                controller.capturing
                                                    ? Icons.stop_rounded
                                                    : Icons.mic_none_rounded,
                                              ),
                                              label: Text(
                                                controller.capturing
                                                    ? '说完了'
                                                    : controller
                                                          .processingSpeech
                                                    ? '处理中…'
                                                    : controller.lessonPhase ==
                                                          'recall'
                                                    ? '说出答案'
                                                    : '跟读',
                                              ),
                                              style: TextButton.styleFrom(
                                                foregroundColor: Colors.white,
                                                backgroundColor: Colors.white12,
                                              ),
                                            ),
                                          if (controller.courseMode &&
                                              controller
                                                  .courseOptions
                                                  .isNotEmpty)
                                            for (final option
                                                in controller.courseOptions)
                                              TextButton(
                                                onPressed: () =>
                                                    controller.respondToCourse(
                                                      option['id']!,
                                                    ),
                                                style: TextButton.styleFrom(
                                                  foregroundColor: Colors.white,
                                                  backgroundColor:
                                                      Colors.white12,
                                                ),
                                                child:
                                                    controller.courseStyle
                                                            .startsWith(
                                                              'child',
                                                            ) &&
                                                        const [
                                                          'apple',
                                                          'banana',
                                                        ].contains(option['id'])
                                                    ? Semantics(
                                                        label: option['label'],
                                                        child: CustomPaint(
                                                          size: const Size(
                                                            42,
                                                            40,
                                                          ),
                                                          painter:
                                                              _FruitPainter(
                                                                option['id']!,
                                                              ),
                                                        ),
                                                      )
                                                    : Text(option['label']!),
                                              )
                                          else if (controller.awaitingResponse)
                                            TextButton.icon(
                                              onPressed:
                                                  controller.completeAttempt,
                                              icon: const Icon(
                                                Icons.check_circle_outline,
                                                size: 20,
                                              ),
                                              label: const Text('我读好了'),
                                              style: TextButton.styleFrom(
                                                foregroundColor: Colors.white,
                                                backgroundColor: Colors.white12,
                                              ),
                                            )
                                          else
                                            TextButton.icon(
                                              onPressed: controller.ready
                                                  ? controller.playing
                                                        ? controller
                                                              .togglePlayback
                                                        : _play
                                                  : null,
                                              icon: Icon(
                                                controller.playing
                                                    ? Icons.stop_rounded
                                                    : Icons.play_arrow_rounded,
                                                size: 20,
                                              ),
                                              label: Text(
                                                controller.playing
                                                    ? '停止'
                                                    : controller.progress == 1
                                                    ? '再练一次'
                                                    : '开始学习',
                                              ),
                                              style: TextButton.styleFrom(
                                                foregroundColor: Colors.white,
                                                backgroundColor: Colors.white12,
                                              ),
                                            ),
                                          if (controller.playing &&
                                              !controller.courseMode)
                                            TextButton(
                                              onPressed:
                                                  controller.replayLesson,
                                              child: const Text(
                                                '再听一次',
                                                style: TextStyle(
                                                  color: Colors.white70,
                                                ),
                                              ),
                                            ),
                                          TextButton(
                                            onPressed: controller.ready
                                                ? () => controller.step(1)
                                                : null,
                                            child: const Text(
                                              '下一个',
                                              style: TextStyle(
                                                color: Colors.white70,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                    if (controller.emotionMode) ...[
                                      const SizedBox(height: 10),
                                      Text(
                                        controller.emotion.label,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: wide ? 26 : 18,
                                        ),
                                      ),
                                      if (box.maxWidth > 700) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                          controller.emotion.description,
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 14,
                                            height: 1.6,
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 12),
                                      DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          value: controller.emotion.id,
                                          isExpanded: true,
                                          dropdownColor: const Color(
                                            0xFF414141,
                                          ),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                          ),
                                          iconEnabledColor: Colors.white70,
                                          items: emotions
                                              .map(
                                                (e) => DropdownMenuItem(
                                                  value: e.id,
                                                  child: Text(e.label),
                                                ),
                                              )
                                              .toList(),
                                          onChanged: (id) {
                                            if (id != null) {
                                              controller.playEmotion(
                                                emotions.indexWhere(
                                                  (e) => e.id == id,
                                                ),
                                              );
                                            }
                                          },
                                        ),
                                      ),
                                      Wrap(
                                        spacing: 4,
                                        children: [
                                          TextButton(
                                            onPressed: controller.ready
                                                ? () => controller.playEmotion(
                                                    controller.emotionIndex,
                                                  )
                                                : null,
                                            child: const Text(
                                              '重播',
                                              style: TextStyle(
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                          TextButton(
                                            onPressed: controller.ready
                                                ? () => controller.playEmotion(
                                                    0,
                                                    all: true,
                                                  )
                                                : null,
                                            child: const Text(
                                              '全部连播',
                                              style: TextStyle(
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                          if (controller.playing)
                                            TextButton(
                                              onPressed:
                                                  controller.togglePlayback,
                                              child: const Text(
                                                '停止',
                                                style: TextStyle(
                                                  color: Colors.white70,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    AnimatedBuilder(
                      animation: controller,
                      builder: (context, _) {
                        if (controller.error == null) {
                          return const SizedBox.shrink();
                        }
                        return Center(
                          child: Material(
                            color: const Color(0xE6222222),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    controller.error!,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  TextButton(
                                    onPressed: controller.retry,
                                    child: const Text('重试'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: MouseRegion(
                        onEnter: (_) => _showControls(),
                        child: SafeArea(
                          top: false,
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              wide ? 28 : 12,
                              12,
                              wide ? 28 : 12,
                              16,
                            ),
                            child: AnimatedOpacity(
                              opacity: _controlsVisible ? 1 : 0,
                              duration: const Duration(milliseconds: 220),
                              child: IgnorePointer(
                                ignoring: !_controlsVisible,
                                child: ExcludeSemantics(
                                  excluding: !_controlsVisible,
                                  child: _controlsVisible
                                      ? _controls(wide)
                                      : const SizedBox.shrink(),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    ),
  );

  Color _soundColor(PhoneticToken token) => token.isWeakEnding
      ? const Color(0xFFDDC5FF)
      : token.isVowel
      ? const Color(0xFFFFCE99)
      : const Color(0xFFAADEFF);

  Widget _pronunciationLine(bool wide) {
    final style = TextStyle(
      color: Colors.white70,
      fontSize: wide ? 22 : 16,
      height: 1.3,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 14,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final token in phoneticTokens(
                  controller.word.phonetic,
                  controller.word.sounds,
                ))
                  if (!token.playable)
                    Text(token.text, style: style)
                  else
                    Semantics(
                      button: true,
                      label: '发音 /${token.text}/',
                      hint: token.isWeakEnding
                          ? '连贯弱读音节'
                          : token.isVowel
                          ? '元音'
                          : '辅音',
                      child: ExcludeSemantics(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: controller.ready
                              ? () {
                                  _hideControls();
                                  controller.playPhoneme(token.text);
                                }
                              : null,
                          child: Container(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 2,
                              vertical: 6,
                            ),
                            padding: EdgeInsets.symmetric(
                              horizontal: wide ? 7 : 5,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: _soundColor(token).withValues(
                                alpha: controller.activeSound == token.text
                                    ? .22
                                    : .08,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              token.text,
                              style: style.copyWith(
                                color: _soundColor(token),
                                decoration: controller.activeSound == token.text
                                    ? TextDecoration.underline
                                    : TextDecoration.none,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
              ],
            ),
            TextButton(
              onPressed: controller.ready
                  ? () {
                      _hideControls();
                      controller.playMeaning();
                    }
                  : null,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                minimumSize: const Size(0, 40),
                foregroundColor: Colors.white70,
              ),
              child: Text(controller.word.meaning, style: style),
            ),
          ],
        ),
      ],
    );
  }

  void _showDemos() {
    _hideControls();
    if (controller.playing) controller.togglePlayback();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF333333),
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.auto_stories_outlined,
                  color: Colors.white70,
                ),
                title: const Text(
                  '课程表演 · apple',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showCourseStyles();
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.school_outlined,
                  color: Colors.white70,
                ),
                title: const Text(
                  '返回日常教学',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  controller.select(controller.index);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.face_retouching_natural,
                  color: Colors.white70,
                ),
                title: const Text(
                  '情绪演示',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  controller.showEmotions();
                },
              ),
              ListTile(
                leading: const Icon(Icons.rotate_right, color: Colors.white70),
                title: const Text(
                  '24 秒连续表演',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  controller.playActingStory();
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.movie_outlined,
                  color: Colors.white70,
                ),
                title: const Text(
                  '10 秒教学表演',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  controller.playPerformance();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCourseStyles() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF333333),
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final entry in const {
                'adult': '成人零基础',
                'child46': '儿童 4—6 岁',
                'child79': '儿童 7—9 岁',
                'child1012': '儿童 10—12 岁',
              }.entries)
                ListTile(
                  title: Text(
                    entry.value,
                    style: const TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    controller.playCourse(style: entry.key);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _controls(bool wide) => AnimatedBuilder(
    animation: Listenable.merge([controller, controller.playbackTick]),
    builder: (context, _) => Material(
      color: const Color(0xC9262626),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 32,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: lessonWords.length,
                separatorBuilder: (_, index) => const SizedBox(width: 6),
                itemBuilder: (context, index) => TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: index == controller.index
                        ? Colors.white24
                        : Colors.transparent,
                    minimumSize: const Size(48, 30),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  onPressed: () {
                    controller.select(index);
                    _showControls();
                  },
                  child: Text(lessonWords[index].id),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (wide)
                  _icon('上一个', Icons.chevron_left, () => controller.step(-1)),
                _icon(
                  controller.playing ? '停止示范' : '播放示范',
                  controller.playing
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  controller.ready ? controller.togglePlayback : null,
                ),
                _icon('下一个', Icons.chevron_right, () => controller.step(1)),
                if (wide) const Spacer(),
                Flexible(
                  child: TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(40, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                    ),
                    onPressed: () {
                      controller.setRate(controller.rate == 1 ? .75 : 1);
                      _showControls();
                    },
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        controller.rate == 1
                            ? (wide ? '正常' : '1×')
                            : (wide ? '慢速 0.75×' : '0.75×'),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
                _icon('重复 3 遍', Icons.repeat_rounded, () {
                  controller.toggleRepeat();
                  _showControls();
                }, selected: controller.repeating),
                if (wide)
                  _icon('放大口型', Icons.zoom_in_rounded, () {
                    controller.toggleFocus();
                    _showControls();
                  }, selected: controller.closeUp),
                _icon('素材与验证信息', Icons.info_outline_rounded, _showInfo),
                _icon('隐藏操作栏', Icons.keyboard_arrow_down, _hideControls),
              ],
            ),
            if (controller.playing)
              LinearProgressIndicator(
                value: controller.progress,
                minHeight: 2,
                color: Colors.white70,
                backgroundColor: Colors.white12,
              ),
          ],
        ),
      ),
    ),
  );

  Widget _icon(
    String label,
    IconData icon,
    VoidCallback? action, {
    bool selected = false,
  }) => IconButton(
    style: IconButton.styleFrom(
      minimumSize: const Size(36, 36),
      maximumSize: const Size(36, 36),
      padding: EdgeInsets.zero,
    ),
    tooltip: label,
    onPressed: action,
    visualDensity: VisualDensity.compact,
    color: selected ? const Color(0xFFFFDFA0) : Colors.white70,
    icon: Icon(icon, size: 23),
  );

  void _showInfo() {
    _hideTimer?.cancel();
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('素材与验证信息'),
        content: SingleChildScrollView(
          child: AnimatedBuilder(
            animation: controller,
            builder: (context, _) => Text(
              '点击单词播放示范；点击空白显示操作栏。\n左右滑动切词；空格播放，方向键切词。\n\n'
              '当前人物：Storm v1.1。\n'
              '运行帧率：${controller.diagnostics['fps'] ?? '…'} FPS\n'
              '帧间隔 P95：${controller.diagnostics['frameP95'] ?? '…'} ms\n'
              '渲染脚本 P95：${controller.diagnostics['cpuP95'] ?? '…'} ms\n'
              '三角面：${controller.diagnostics['triangles'] ?? '…'}\n'
              '渲染器：${controller.diagnostics['deviceRenderer'] ?? '…'}\n\n'
              '语音使用腾讯云超自然大模型 2.0；跟读与回答可使用新版评测及 ASR 2.0。口型用于视听示范，尚未经过逐音素教学校准。手机性能需真机验证。\n\n'
              'Storm Rig (CC) Blender Foundation | studio.blender.org\n'
              '来源：https://studio.blender.org/characters/storm/v1/\n'
              '许可：CC BY（以原素材许可为准）\n'
              '修改：贴图压缩、材质简化、动作烘焙、GLB 转换。',
              style: const TextStyle(height: 1.6),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showControls();
            },
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }
}

class _FruitPainter extends CustomPainter {
  final String fruit;
  const _FruitPainter(this.fruit);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 42, size.height / 40);
    if (fruit == 'apple') {
      final body = Path()
        ..moveTo(21, 12)
        ..cubicTo(5, 3, 2, 22, 12, 34)
        ..cubicTo(16, 38, 19, 33, 21, 34)
        ..cubicTo(25, 38, 30, 37, 35, 25)
        ..cubicTo(42, 9, 28, 5, 21, 12);
      canvas.drawPath(body, Paint()..color = const Color(0xFFE9907D));
      canvas.drawLine(
        const Offset(21, 12),
        const Offset(23, 3),
        Paint()
          ..color = Colors.white70
          ..strokeWidth = 2,
      );
      canvas.drawOval(
        const Rect.fromLTWH(24, 3, 10, 5),
        Paint()..color = const Color(0xFFB0C798),
      );
    } else {
      final body = Path()
        ..moveTo(7, 7)
        ..cubicTo(6, 28, 25, 31, 36, 12)
        ..cubicTo(35, 38, 8, 43, 5, 18)
        ..close();
      canvas.drawPath(body, Paint()..color = const Color(0xFFE8CF83));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FruitPainter oldDelegate) => oldDelegate.fruit != fruit;
}
