import 'dart:math' as math;
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../application/lesson_controller.dart';
import '../domain/course_lexicon.dart';
import 'learning_text.dart';
import 'ipa_text.dart';

class AdultCoursePanel extends StatelessWidget {
  const AdultCoursePanel({super.key, required this.controller});
  final LessonController controller;
  Widget fruit(String word, {double size = 72}) => Semantics(
    label: word == 'apple' ? '苹果图片' : '香蕉图片',
    child: SvgPicture.asset(
      'assets/avatar/images/${word == 'apple' ? 'apple' : 'banana'}.svg',
      width: size,
      height: size,
    ),
  );
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final c = controller,
          compact = box.maxHeight < 440,
          summary = c.courseStep == 'summary';
      final sentence = c.coachSentence.isNotEmpty
          ? c.coachSentence
          : c.courseDisplay;
      final entry = courseLexicon[c.courseDisplay.toLowerCase()];
      // Only actual answer cards may enter the screen. Legacy transition
      // actions can still exist in director data but must never flash here.
      final visibleOptions = c.courseOptions
          .where(
            (o) => c.courseStep == 'extension_gate'
                ? const {'next', 'skip'}.contains(o['id']) &&
                      const {'学习红苹果', '先去复习'}.contains(o['label'])
                : c.lessonPhase == 'choice' &&
                      const {
                        'apple',
                        'banana',
                        'choose_apple',
                        'choose_banana',
                        'phrase_apple',
                        'phrase_banana',
                      }.contains(o['id']),
          )
          .toList();
      final choice = visibleOptions.isNotEmpty;
      final showEnglish = !c.hideAnswer || c.coachSentence.isNotEmpty;
      final body = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.courseChapter,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        letterSpacing: .6,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: ((c.coursePosition + 1) / c.courseTotal).clamp(
                          0,
                          1,
                        ),
                        minHeight: 2,
                        color: const Color(0xFFBDE5DD),
                        backgroundColor: Colors.white12,
                      ),
                    ),
                  ],
                ),
              ),
              if (c.coursePicture.isNotEmpty &&
                  !choice &&
                  !summary &&
                  !c.coursePaused) ...[
                const SizedBox(width: 16),
                fruit(c.coursePicture, size: compact ? 48 : 64),
              ],
            ],
          ),
          SizedBox(height: compact ? 12 : 22),
          if (c.coursePaused) ...[
            const Text(
              '休息一下',
              style: TextStyle(fontSize: 28, color: Colors.white),
            ),
            const SizedBox(height: 12),
            const Text('轻触人物继续，或到设置调整课程。'),
          ] else if (summary) ...[
            const Text(
              '今天，又向前了一步。',
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 15),
            Text(
              '+${c.vocabulary.newThisCourse.length}',
              style: const TextStyle(
                fontSize: 58,
                fontWeight: FontWeight.w300,
                color: Color(0xFFBDE5DD),
              ),
            ),
            Text('本课新接触 · 累计 ${c.vocabulary.seen.length} 词'),
            const SizedBox(height: 10),
            Text(
              (c.vocabulary.newThisCourse.toList()..sort()).join(' · '),
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 14),
            const Text('轻触人物，再练一轮。', style: TextStyle(color: Colors.white60)),
          ] else ...[
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: Align(
                key: ValueKey(
                  '${c.lessonPhase}:${c.playing}:${c.automaticState}',
                ),
                alignment: Alignment.centerLeft,
                child: Text(
                  choice
                      ? '听音 · 选出图片'
                      : c.playing ||
                            !const {
                              'listen',
                              'recall',
                              'choice',
                            }.contains(c.lessonPhase)
                      ? '先听示范'
                      : c.automaticState == 'processing'
                      ? '正在确认你的表达'
                      : c.automaticState == 'correction'
                      ? '一起把这一处练好'
                      : '轮到你说了',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFFBDE5DD),
                    letterSpacing: 1.1,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            if (showEnglish && sentence.isNotEmpty)
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                transitionBuilder: (child, a) => FadeTransition(
                  opacity: a,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: .96, end: 1).animate(
                      CurvedAnimation(parent: a, curve: Curves.easeOutBack),
                    ),
                    child: child,
                  ),
                ),
                child: LearningText(
                  sentence,
                  key: ValueKey(sentence),
                  controller: c,
                  size: compact ? 34 : 42,
                ),
              ),
            if (entry != null && !c.hideAnswer && c.coachSentence.isEmpty)
              IpaText(
                entry.ipa,
                controller: c,
                style: const TextStyle(
                  fontFamily: 'NotoSansIPA',
                  fontSize: 21,
                  color: Colors.white60,
                ),
              ),
            const SizedBox(height: 10),
            IpaText(
              c.courseText,
              controller: c,
              style: TextStyle(
                fontSize: compact ? 16 : 18,
                color: Colors.white70,
                height: 1.5,
              ),
            ),
            if (choice)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    for (final option in visibleOptions)
                      Semantics(
                        button: true,
                        label: option['label'],
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () => c.respondToCourse(option['id']!),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: .08),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child:
                                [
                                  'apple',
                                  'banana',
                                  'choose_apple',
                                  'choose_banana',
                                  'phrase_apple',
                                  'phrase_banana',
                                ].contains(option['id'])
                                ? fruit(
                                    option['id']!.contains('banana')
                                        ? 'banana'
                                        : 'apple',
                                    size: 54,
                                  )
                                : Text(option['label']!),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            if (c.automaticState == 'correction')
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: c.automaticState == 'success'
                    ? EdgeInsets.zero
                    : const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: c.automaticState == 'success'
                      ? Colors.transparent
                      : const Color(0xFFFFD1A2).withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: IpaText(
                  c.automaticFeedback,
                  controller: c,
                  style: TextStyle(
                    color: c.automaticState == 'success'
                        ? const Color(0xFFBDE5DD)
                        : const Color(0xFFFFD1A2),
                    fontSize: compact ? 15 : 17,
                    height: 1.5,
                  ),
                ),
              ),
            const SizedBox(height: 10),
            if (c.automaticState != 'success') ListeningLine(controller: c),
          ],
        ],
      );
      return Align(
        alignment: Alignment.centerLeft,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: box.maxWidth,
            child: DefaultTextStyle(
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'NotoSansIPA',
                fontFamilyFallback: ['NotoSansSC'],
                fontSize: 14,
                height: 1.4,
              ),
              child: Semantics(
                container: true,
                explicitChildNodes: true,
                child: body,
              ),
            ),
          ),
        ),
      );
    },
  );
}

class ListeningLine extends StatelessWidget {
  const ListeningLine({super.key, required this.controller});
  final LessonController controller;
  @override
  Widget build(BuildContext context) {
    final c = controller, thinking = c.automaticState == 'processing';
    final listening = c.automaticReading;
    final label = c.automaticStarting
        ? '请在浏览器中允许麦克风'
        : !c.automaticReading
        ? '麦克风未开启 · 到设置重试'
        : thinking
        ? '正在听懂你的话…'
        : c.playing
        ? '麦克风已连接 · 示范结束后评测'
        : '我在听，直接说就好';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            MicWave(level: c.micLevel, active: listening),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 14, color: Colors.white60),
              ),
            ),
          ],
        ),
        if (c.liveTranscript.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: LiveTypingText(
              text: c.liveTranscript,
              listening: listening && !c.playing && !thinking,
            ),
          ),
        if (c.automaticState == 'error')
          Text(
            c.automaticFeedback,
            style: const TextStyle(color: Color(0xFFFFD1A2), fontSize: 12),
          ),
      ],
    );
  }
}

class MicWave extends StatefulWidget {
  const MicWave({super.key, required this.level, required this.active});
  final double level;
  final bool active;
  @override
  State<MicWave> createState() => _MicWaveState();
}

class _MicWaveState extends State<MicWave> {
  final samples = List<double>.filled(17, 0, growable: true);
  @override
  void didUpdateWidget(MicWave old) {
    super.didUpdateWidget(old);
    if (!widget.active) {
      samples.fillRange(0, samples.length, 0);
      return;
    }
    samples.removeAt(0);
    samples.add(widget.level.clamp(0, 1));
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.active ? '麦克风已连接，实时音量' : '麦克风未连接',
    child: SizedBox(
      width: 84,
      height: 30,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (var i = 0; i < samples.length; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 80),
              width: 2.8,
              height: 3 + samples[i] * 25,
              decoration: BoxDecoration(
                color: widget.active
                    ? Color.lerp(
                        const Color(0xFF78B8B0),
                        const Color(0xFFE2FFF2),
                        samples[i],
                      )
                    : Colors.white30,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
        ],
      ),
    ),
  );
}

/// Only reveals characters received from ASR; never fills from the lesson target.
class LiveTypingText extends StatefulWidget {
  const LiveTypingText({
    super.key,
    required this.text,
    required this.listening,
  });
  final String text;
  final bool listening;
  @override
  State<LiveTypingText> createState() => _LiveTypingTextState();
}

class _LiveTypingTextState extends State<LiveTypingText> {
  String shown = '';
  Timer? timer;
  @override
  void initState() {
    super.initState();
    _update();
  }

  @override
  void didUpdateWidget(LiveTypingText old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) _update();
  }

  void _update() {
    timer?.cancel();
    var prefix = 0;
    while (prefix < shown.length &&
        prefix < widget.text.length &&
        shown[prefix] == widget.text[prefix]) {
      prefix++;
    }
    shown = shown.substring(0, prefix);
    timer = Timer.periodic(const Duration(milliseconds: 16), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(
        () => shown = widget.text.substring(
          0,
          math.min(shown.length + 2, widget.text.length),
        ),
      );
      if (shown == widget.text) t.cancel();
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text(
    '${MediaQuery.disableAnimationsOf(context) ? widget.text : shown}${widget.listening ? ' ▍' : ''}',
    style: const TextStyle(fontSize: 18, color: Color(0xFFD2E6E2), height: 1.5),
  );
}
