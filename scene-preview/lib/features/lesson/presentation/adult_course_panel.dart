import '../../../core/avatar/scene/course_resources.dart';

import 'dart:math' as math;
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../application/lesson_controller.dart';
import '../domain/course_lexicon.dart';
import 'learning_text.dart';
import 'ipa_text.dart';
import 'lesson_content_frame.dart';
import 'lesson_layout.dart';
import 'teaching_trial_panel.dart';

class AdultCoursePanel extends StatelessWidget {
  const AdultCoursePanel({super.key, required this.controller});
  final LessonController controller;
  Widget fruit(String word, {double size = 72, String? meaning}) => Semantics(
    label: '${meaning ?? courseLexicon[word]?.meaning ?? word}图片',
    child: SvgPicture.asset(
      bundle: CourseResources.instance,
      'assets/avatar/images/$word.svg',
      width: size,
      height: size,
    ),
  );
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      if (controller.teachingCard != null) {
        return TeachingTrialPanel(controller: controller);
      }
      final c = controller,
          type = LessonType(box.biggest),
          summary = c.courseStep == 'summary';
      final headerHeight = math.max(
        type.header,
        MediaQuery.textScalerOf(context).scale(type.title) * 2.6 + 14,
      );
      final sentence = c.coachSentence.isNotEmpty
          ? c.coachSentence
          : c.courseDisplay;
      final entry = courseLexicon[c.courseDisplay.toLowerCase()];
      final displayIpa =
          entry?.ipa ??
          c.reviewIpa(
            c.courseDisplay.toLowerCase().replaceAll(RegExp(r'[.!?]'), ''),
          );
      // Only actual answer cards may enter the screen. Legacy transition
      // actions can still exist in director data but must never flash here.
      final visibleOptions = c.courseOptions
          .where(
            (o) => (c.courseStep == 'extension_gate'
                ? const {'next', 'skip'}.contains(o['id']) &&
                      const {'学习红苹果', '结束本课'}.contains(o['label'])
                : c.lessonPhase == 'choice' &&
                      (o['id']!.startsWith('answer_') ||
                          const {
                            'apple',
                            'banana',
                            'choose_apple',
                            'choose_banana',
                            'phrase_apple',
                            'phrase_banana',
                          }.contains(o['id']))),
          )
          .toList();
      final choice = visibleOptions.isNotEmpty;
      final comparisonPicture = RegExp(
        r'^(count_|size_|(?:one|two|three|four|five)_)',
      ).hasMatch(c.coursePicture);
      final showEnglish = !c.hideAnswer || c.coachSentence.isNotEmpty;
      final body = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: headerHeight,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.courseChapter,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: type.title,
                          fontWeight: FontWeight.w600,
                          letterSpacing: .6,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: c.courseProgress,
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
                  fruit(
                    c.coursePicture,
                    meaning: c.courseText,
                    size: (comparisonPicture ? 72 : 64) * type.scale,
                  ),
                ],
              ],
            ),
          ),
          if (c.coursePaused || summary) SizedBox(height: type.gap),
          if (c.coursePaused) ...[
            Text(
              '休息一下',
              style: TextStyle(fontSize: type.title + 6, color: Colors.white),
            ),
            const SizedBox(height: 12),
            const Text('轻触任意位置继续，或从「课程」选择下一课。'),
          ] else if (summary) ...[
            Text(
              c.verifiedCourseClosing ?? c.address('本节课我们就学到这里。'),
              style: TextStyle(
                fontSize: type.title + 4,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 15),
            Text(
              '+${c.confirmedCourseWords?.length ?? c.vocabulary.newThisCourse.length}',
              style: TextStyle(
                fontSize: 66 * type.scale,
                fontWeight: FontWeight.w300,
                color: Color(0xFFBDE5DD),
              ),
            ),
            Text(
              c.confirmedCourseWords == null
                  ? '本课新接触 · 累计 ${c.vocabulary.seen.length} 词'
                  : '本课新确认 · 累计 ${c.confirmedWordTotal} 词',
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 20,
              runSpacing: 10,
              children: [
                for (final word in c.courseReviewWords)
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: () => c.previewWord(word),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Text(
                            word == 'i' ? 'I' : word,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: type.body,
                            ),
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () => c.previewWord(word),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: IpaText(
                            c.reviewIpa(word),
                            controller: c,
                            style: TextStyle(
                              color: Color(0xFFBDE5DD),
                              fontSize: type.caption,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              c.closingCheer,
              style: TextStyle(
                color: const Color(0xFFBDE5DD),
                fontSize: type.body,
              ),
            ),
            if (c.nextCourse != null) const SizedBox(height: 24),
            if (c.nextCourse != null)
              TextButton(
                onPressed: () => c.selectCourse(c.nextCourse!.id),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFBDE5DD),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  alignment: Alignment.centerLeft,
                ),
                child: Text(
                  '下一课  ·  ${c.nextCourse!.title.replaceFirst(RegExp(r"^\d+\s*·\s*"), "")}  →',
                ),
              ),
          ] else ...[
            SizedBox(
              height:
                  MediaQuery.textScalerOf(context).scale(type.caption) * 1.8,
              child: AnimatedSwitcher(
                layoutBuilder: lessonSwitchLayout,
                duration: const Duration(milliseconds: 220),
                child: Align(
                  key: ValueKey(
                    '${c.lessonPhase}:${c.playing}:${c.automaticState}',
                  ),
                  alignment: Alignment.centerLeft,
                  child: Text(
                    choice
                        ? (visibleOptions.any(
                                (o) => o['id']!.startsWith('answer_'),
                              )
                              ? '听音 · 选择意思'
                              : '听音 · 选出图片')
                        : c.lessonPhase == 'meaning'
                        ? '认识意思'
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
                    style: TextStyle(
                      fontSize: type.caption,
                      color: Color(0xFFBDE5DD),
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
              ),
            ),
            if (displayIpa.isNotEmpty &&
                !c.hideAnswer &&
                c.coachSentence.isEmpty)
              Padding(
                padding: EdgeInsets.only(top: type.gap / 2, bottom: type.gap),
                child: IpaText(
                  displayIpa,
                  controller: c,
                  style: TextStyle(
                    fontFamily: 'NotoSansIPA',
                    fontSize: type.ipa,
                    color: Colors.white70,
                  ),
                ),
              ),
            if (showEnglish && sentence.isNotEmpty)
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                layoutBuilder: lessonSwitchLayout,
                transitionBuilder: (child, a) =>
                    FadeTransition(opacity: a, child: child),
                child: LearningText(
                  sentence,
                  key: ValueKey(sentence),
                  controller: c,
                  size: type.main(sentence),
                ),
              ),
            SizedBox(height: type.gap),
            IpaText(
              c.courseText,
              controller: c,
              style: TextStyle(
                fontSize: type.body,
                color: Colors.white70,
                height: 1.5,
              ),
            ),
            if (visibleOptions.isNotEmpty)
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
                    fontSize: type.body,
                    height: 1.5,
                  ),
                ),
              ),
            const SizedBox(height: 10),
            if (c.automaticState != 'success') ListeningLine(controller: c),
          ],
        ],
      );
      return LessonContentFrame(
        headerHeight: headerHeight,
        topPadding: 0,
        header: body.children.first,
        child: DefaultTextStyle(
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'NotoSansIPA',
            fontFamilyFallback: ['NotoSansSC'],
            fontSize: type.body,
            height: 1.4,
          ),
          child: Semantics(
            container: true,
            explicitChildNodes: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: body.children.skip(1).toList(),
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
          active:
              listening &&
              !c.playing &&
              !thinking &&
              !c.coursePaused &&
              c.automaticState != 'error',
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

/// Five rounded voice bars match EntryIdentity; amplitude is microphone-only.
class MicWave extends StatelessWidget {
  const MicWave({super.key, required this.level, required this.active});
  final double level;
  final bool active;
  @override
  Widget build(BuildContext context) {
    final amplitude = active && level.isFinite ? level.clamp(0.0, 1.0) : 0.0;
    return Semantics(
      label: active ? '正在收音' : '收音暂停',
      child: SizedBox(
        width: 56,
        height: 40,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 0; i < 5; i++)
              AnimatedContainer(
                key: ValueKey('lesson-voice-bar-$i'),
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 80),
                width: 6,
                height:
                    [10.0, 16.0, 22.0, 16.0, 10.0][i] +
                    [6.0, 12.0, 18.0, 12.0, 6.0][i] * amplitude,
                decoration: BoxDecoration(
                  color: active ? const Color(0xFFBDE5DD) : Colors.white30,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
          ],
        ),
      ),
    );
  }
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
