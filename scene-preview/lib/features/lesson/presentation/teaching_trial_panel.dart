import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../application/lesson_controller.dart';
import 'ipa_text.dart';
import 'learning_text.dart';
import 'trial_presentation.dart';

const _mint = Color(0xFFBDE5DD), _amber = Color(0xFFFFD4A3);

class TeachingTrialPanel extends StatelessWidget {
  const TeachingTrialPanel({super.key, required this.controller});
  final LessonController controller;
  Widget copy(
    String text,
    TrialType t, {
    Color color = Colors.white70,
    double? size,
  }) => Text(
    text,
    style: TextStyle(
      fontFamily: 'NotoSansSC',
      fontSize: size ?? t.body,
      color: color,
      height: 1.35,
    ),
  );
  Widget english(String text, TrialType t, {double? size}) => LearningText(
    text,
    controller: controller,
    size: size ?? t.sentence,
    animate: false,
  );
  Widget ipa(String word, TrialType t, {String? highlight, double? size}) =>
      IpaText(
        controller.reviewIpa(word),
        controller: controller,
        compact: true,
        minimumTargetHeight: 44,
        highlight: highlight,
        style: TextStyle(
          fontFamily: 'NotoSansIPA',
          fontSize: size ?? t.ipa,
          color: Colors.white70,
        ),
      );
  Widget pronunciations(Map block, TrialType t) {
    final words = List<String>.from(block['words']);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final word in words)
          Flexible(
            child: Padding(
              padding: EdgeInsets.only(
                right: word == words.last ? 0 : t.gap * 2,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (block['showWords'] == true)
                    copy(word, t, size: t.caption, color: _mint),
                  ipa(word, t),
                ],
              ),
            ),
          ),
      ],
    );
  }

  List<Widget> blocks(List<dynamic> board, TrialType t) {
    final out = <Widget>[];
    void add(Widget w) {
      if (out.isNotEmpty) out.add(SizedBox(height: t.gap));
      out.add(w);
    }

    for (var i = 0; i < board.length; i++) {
      final b = board[i] as Map, kind = b['kind'];
      // Word and meaning share a heading; the pronunciation always occupies
      // its own next line. This leaves room for the phrase in small landscapes.
      if (kind == 'english' &&
          b['role'] == 'word' &&
          i + 2 < board.length &&
          board[i + 1]['kind'] == 'pronunciations' &&
          board[i + 2]['kind'] == 'meaning') {
        add(
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(child: english(b['text'], t, size: t.word)),
              SizedBox(width: t.gap * 2),
              Flexible(child: copy(board[i + 2]['text'], t, color: _mint)),
            ],
          ),
        );
        add(pronunciations(board[i + 1], t));
        i += 2;
        continue;
      }
      if (kind == 'pronunciations') {
        add(pronunciations(b,t));
      } else if (kind == 'pair') {
        if (RegExp(r'^[A-Za-z]+$').hasMatch(b['text'])) {
          add(
            Row(
              children: [
                Flexible(
                  child: english(
                    b['text'],
                    t,
                    size: math.max(20, 25 * t.scale),
                  ),
                ),
                SizedBox(width: t.gap * 2),
                Flexible(child: copy(b['meaning'], t, color: _mint)),
              ],
            ),
          );
        } else {
          add(
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                english(b['text'], t, size: math.max(20, 25 * t.scale)),
                SizedBox(height: t.gap / 2),
                copy(b['meaning'], t, color: _mint),
              ],
            ),
          );
        }
      } else if (kind == 'english') {
        add(
          english(
            b['text'],
            t,
            size: b['role'] == 'word'
                ? t.word
                : b['role'] == 'context'
                ? math.max(20, 25 * t.scale)
                : t.sentence,
          ),
        );
      } else {
        add(
          copy(
            b['text'],
            t,
            color: kind == 'meaning' || kind == 'caption'
                ? _mint
                : Colors.white70,
          ),
        );
      }
    }
    return out;
  }

  Widget repairView(Map card, TrialType t) {
    final r = card['repair'] as Map,
        original = r['original'] as String,
        focus = r['word'] ?? '';
    final chunks = RegExp(r"[A-Za-z]+(?:'[A-Za-z]+)?|[^A-Za-z]+")
        .allMatches(original);
    final message = card['feedback'] as String? ?? '';
    final instruction = message.contains('改法：')
        ? message.split('改法：').last
        : message.replaceAll(RegExp(r'当前重点是 /[^/]+/。'), '');
    final target = r['target'] as String,
        word = RegExp(r'^[A-Za-z]+$').hasMatch(target);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: '放回原表达：'),
              for (final m in chunks)
                TextSpan(
                  text: m[0],
                  style: m[0]!.toLowerCase() == focus
                      ? const TextStyle(
                          color: _amber,
                          decoration: TextDecoration.underline,
                        )
                      : null,
                ),
            ],
          ),
          style: TextStyle(
            fontFamily: 'NotoSansIPA',
            fontSize: t.caption,
            color: Colors.white60,
            height: 1.35,
          ),
        ),
        SizedBox(height: t.gap),
        english(target, t, size: word ? t.word : t.sentence),
        if (controller.reviewIpa(target).isNotEmpty) ...[
          SizedBox(height: t.gap),
          ipa(target, t, highlight: r['phone']),
        ],
        SizedBox(height: t.gap),
        copy(instruction, t, color: _amber),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final c = controller,
          card = c.teachingCard!,
          t = TrialType(box.biggest),
          summary = card['summary'] == true;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            key: const ValueKey('trial-course-header'),
            height: t.header,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: t.headerRow,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          c.activeCourse.title,
                          style: TextStyle(
                            fontFamily: 'NotoSansSC',
                            fontSize: t.title,
                            color: Colors.white70,
                            height: 1.2,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (card['hasSpeechTarget'] == true && !summary)
                        SizedBox(width: 42, child: _Listening(controller: c)),
                    ],
                  ),
                ),
                SizedBox(height: t.gap),
                LinearProgressIndicator(
                  key: const ValueKey('trial-course-progress'),
                  value: c.courseProgress,
                  minHeight: 1.5,
                  color: _mint.withValues(alpha: .75),
                  backgroundColor: Colors.white12,
                ),
              ],
            ),
          ),
          Expanded(
            child: summary
                ? _Vocabulary(controller: c, type: t)
                : Align(
                    alignment: Alignment.topLeft,
                    child: Column(
                      key: ValueKey('trial-board-${card['id']}'),
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (card['repair'] != null)
                          repairView(card, t)
                        else
                          ...blocks(card['board'], t),
                        if (card['paused'] == true) ...[
                          SizedBox(height: t.gap),
                          copy('点人物继续当前小段。', t, size: t.caption),
                        ],
                        if (c.automaticFeedback.isNotEmpty &&
                            card['repair'] == null &&
                            !c.playing &&
                            c.automaticState != 'success') ...[
                          SizedBox(height: t.gap),
                          copy(
                            c.automaticFeedback,
                            t,
                            color: _amber,
                            size: t.caption,
                          ),
                        ],
                      ],
                    ),
                  ),
          ),
        ],
      );
    },
  );
}

class _Vocabulary extends StatelessWidget {
  const _Vocabulary({required this.controller, required this.type});
  final LessonController controller;
  final TrialType type;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final c = controller, t = type, words = c.courseReviewWords;
      if (c.reviewPage == 0) return _Summary(controller: c, type: t);
      final columns = box.maxWidth >= 570 ? 3 : 2;
      final titleHeight = t.caption * 1.4 + t.gap,
          footerHeight = t.caption * 1.4 + t.gap;
      final rowHeight = math.max(75.0, 28 * t.scale + 44 + t.gap);
      final rows = ((box.maxHeight - titleHeight - footerHeight) / rowHeight)
          .floor()
          .clamp(1, 20);
      final size = rows * columns,
          pages = (words.length / size).ceil().clamp(1, 100),
          page = (c.reviewPage - 1).clamp(0, pages - 1);
      if (c.reviewPageSize != size)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) c.configureReviewPageSize(size);
        });
      final current = words.skip(page * size).take(size).toList();
      final counts =
          c.teachingCard?['learningSummary']?['counts'] as Map? ?? {};
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: titleHeight,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '本课完整词表 · ${words.length} 词',
                    style: TextStyle(
                      fontFamily: 'NotoSansSC',
                      fontSize: t.caption,
                      color: _mint,
                    ),
                  ),
                ),
                Text(
                  '${page + 1} / $pages',
                  style: TextStyle(fontSize: t.caption, color: Colors.white54),
                ),
              ],
            ),
          ),
          for (var row = 0; row < rows && row * columns < current.length; row++)
            SizedBox(
              height: rowHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var col = 0; col < columns; col++)
                    Expanded(
                      child: col + row * columns >= current.length
                          ? const SizedBox()
                          : Padding(
                              padding: EdgeInsets.only(
                                right: col == columns - 1 ? 0 : t.gap,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  GestureDetector(
                                    onTap: () => c.previewWord(
                                      current[row * columns + col],
                                    ),
                                    behavior: HitTestBehavior.opaque,
                                    child: Text(
                                      current[row * columns + col],
                                      style: TextStyle(
                                        fontFamily: 'NotoSansIPA',
                                        fontSize: math.max(17, 22 * t.scale),
                                        color: Colors.white,
                                        height: 1.2,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  IpaText(
                                    c.reviewIpa(current[row * columns + col]),
                                    controller: c,
                                    compact: true,
                                    minimumTargetHeight: 44,
                                    style: TextStyle(
                                      fontFamily: 'NotoSansIPA',
                                      fontSize: math.max(16, 19 * t.scale),
                                      color: Colors.white60,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                ],
              ),
            ),
          const Spacer(),
          SizedBox(
            height: footerHeight,
            child: Text(
              counts.isEmpty
                  ? '支持级别按实际表现记录'
                  : '跟读 ${counts['follow'] ?? 0} · 提示表达 ${counts['supported'] ?? 0} · 变式 ${counts['transfer'] ?? 0}',
              style: TextStyle(
                fontFamily: 'NotoSansSC',
                fontSize: t.caption,
                color: Colors.white54,
              ),
            ),
          ),
        ],
      );
    },
  );
}

class _Listening extends StatelessWidget {
  const _Listening({required this.controller});
  final LessonController controller;
  @override
  Widget build(BuildContext context) {
    final c = controller,
        processing = c.automaticState == 'processing',
        active =
            c.automaticReading &&
            !c.playing &&
            !processing &&
            !c.coursePaused &&
            c.automaticState != 'error';
    final amplitude = active ? c.micLevel.clamp(0, 1) : 0.0;
    return Semantics(
      label: processing
          ? '正在确认'
          : active
          ? '正在收音'
          : c.playing
          ? '示范播放中'
          : '收音暂停',
      child: SizedBox(
        width: 42,
        height: 24,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 0; i < 5; i++)
              AnimatedContainer(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 90),
                width: 4,
                height:
                    [5.0, 10.0, 15.0, 10.0, 5.0][i] +
                    amplitude * [2.0, 3.0, 5.0, 3.0, 2.0][i],
                decoration: BoxDecoration(
                  color: processing
                      ? _amber
                      : active
                      ? _mint
                      : Colors.white30,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.controller, required this.type});
  final LessonController controller;
  final TrialType type;
  @override
  Widget build(BuildContext context) {
    final c = controller,
        t = type,
        s = c.teachingCard?['learningSummary'] as Map? ?? {};
    final counts = s['counts'] as Map? ?? {},
        sentences = List<String>.from(s['sentences'] ?? []),
        review = List<String>.from(s['review'] ?? []);
    Widget copy(String value, {Color color = Colors.white70}) => Text(
      value,
      style: TextStyle(
        fontFamily: 'NotoSansSC',
        fontSize: t.body,
        color: color,
        height: 1.35,
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        copy('本次实际表现', color: _mint),
        SizedBox(height: t.gap),
        if (sentences.isNotEmpty) ...[
          LearningText(
            sentences.last,
            controller: c,
            size: t.sentence,
            animate: false,
          ),
          SizedBox(height: t.gap),
        ],
        copy(
          counts.isEmpty
              ? '正在整理本次实际记录。'
              : '跟读 ${counts['follow'] ?? 0} · 提示表达 ${counts['supported'] ?? 0} · 变式 ${counts['transfer'] ?? 0}',
        ),
        SizedBox(height: t.gap),
        if (review.isNotEmpty) copy('待复习：${review.join('、')}', color: _amber),
        if ((s['skipped'] ?? 0) > 0) copy('跳过 ${s['skipped']} 段，未记作完成。'),
        const Spacer(),
        Text(
          '完整 ${c.courseReviewWords.length} 词词表 · 用右箭头查看',
          style: TextStyle(
            fontFamily: 'NotoSansSC',
            fontSize: t.caption,
            color: Colors.white54,
          ),
        ),
      ],
    );
  }
}
