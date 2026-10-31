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
    label: '${courseLexicon[word]?.meaning ?? word}图片',
    child: SvgPicture.asset(
      'assets/avatar/images/$word.svg',
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
                      const {'学习红苹果', '结束本课'}.contains(o['label'])
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
            Text(
              c.address('本节课我们就学到这里。'),
              style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w600),
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
            Text(
              c.closingCheer,
              style: const TextStyle(color: Color(0xFFBDE5DD), fontSize: 18),
            ),
            if (c.nextCourse != null)
              TextButton(
                onPressed: () => c.selectCourse(c.nextCourse!.id),
                child: Text('下一课 · ${c.nextCourse!.title.substring(5)} →'),
              ),
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
                      : c.courseStep == 'apple_practice'
                      ? c.address('轮到你说了')
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        MicWave(
          level: c.micLevel,
          active: listening && !c.playing && !thinking,
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
  final samples = List<double>.filled(5, 0, growable: true);
  @override
  void didUpdateWidget(MicWave old) {
    super.didUpdateWidget(old);
    if (!widget.active || widget.level <= 0) {
      samples.fillRange(0, samples.length, 0);
      return;
    }
    samples.removeAt(0);
    samples.add(widget.level.clamp(0, 1));
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.active ? '收音提示' : '收音提示静止',
    child: SizedBox(
      width: 24,
      height: 14,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (var i = 0; i < samples.length; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 2,
              height: 2 + samples[i] * 7,
              decoration: BoxDecoration(
                color: widget.active
                    ? Color.lerp(
                        const Color(0x6678B8B0),
                        const Color(0x9978B8B0),
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
    MediaQuery.disableAnimationsOf(context) ? widget.text : shown,
    style: const TextStyle(fontSize: 18, color: Color(0xFFD2E6E2), height: 1.5),
  );
}
