import 'package:flutter/material.dart';

import '../application/lesson_controller.dart';
import '../domain/course_lexicon.dart';
import 'fruit_painter.dart';
import 'learning_text.dart';

class AdultCoursePanel extends StatelessWidget {
  const AdultCoursePanel({super.key, required this.controller});
  final LessonController controller;
  Widget fruit(String word, {double size = 52}) => Semantics(
    label: word == 'apple' ? '苹果图片' : '香蕉图片',
    child: CustomPaint(
      size: Size(size, size * .95),
      painter: FruitPainter(word),
    ),
  );

  void sounds(BuildContext context, String word) {
    final entries = word == 'apple'
        ? const [
            ('æ', 'phoneme_ae'),
            ('p', 'phoneme_p'),
            ('ə', 'phoneme_schwa'),
            ('l', 'phoneme_l'),
          ]
        : const [
            ('b', 'phoneme_b'),
            ('ə', 'phoneme_schwa'),
            ('n', 'phoneme_n'),
            ('æ', 'phoneme_ae'),
          ];
    showDialog<void>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('独立音标参考'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              courseLexicon[word]!.ipa,
              style: const TextStyle(
                fontFamily: 'NotoSansIPA',
                fontFamilyFallback: ['NotoSansSC'],
                fontSize: 24,
              ),
            ),
            Text(
              word == 'apple'
                  ? '整词有两个音节，重音在前。/əl/ 是组合，不是单个音标。'
                  : '整词有三个音节，重音在中间。重复的 /n/、/ə/ 是词本身的组成，不额外重复播放。',
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                for (final e in entries)
                  TextButton(
                    onPressed: () {
                      Navigator.pop(dialog);
                      controller.previewCourse(e.$2);
                    },
                    child: Text(
                      '/${e.$1}/',
                      style: const TextStyle(
                        fontFamily: 'NotoSansIPA',
                        fontFamilyFallback: ['NotoSansSC'],
                        fontSize: 22,
                      ),
                    ),
                  ),
              ],
            ),
            const Text(
              '独立录音，非单词切片。音标是发音参考，不是英文字母名；整词以美式示范为准。',
              style: TextStyle(fontSize: 13),
            ),
            const Text(
              '来源：Ruben Schachtenhaufen（CC0）；/ə/ 为 Wikimedia Commons 参考录音（CC BY-SA 3.0）。完整署名和链接见音频资源中的 IPA-reference-attribution.json。',
              style: TextStyle(fontSize: 11),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final c = controller,
          summary = c.courseStep == 'summary',
          compact = box.maxHeight < 480;
      final data = c.courseCheckpoint ?? {};
      final displayKey = c.courseDisplay
          .replaceAll(RegExp('[^A-Za-z]'), '')
          .toLowerCase();
      final entry = courseLexicon[displayKey];
      Widget button(String label, VoidCallback? action, {Widget? icon}) =>
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.white12,
              minimumSize: const Size(40, 36),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            ),
            onPressed: action,
            child: icon == null
                ? Text(label)
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [icon, const SizedBox(width: 6), Text(label)],
                  ),
          );
      final content = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '成人零基础 · ${c.courseChapter}',
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ),
              if (!summary && !c.coursePaused)
                IconButton(
                  tooltip: '暂停',
                  visualDensity: VisualDensity.compact,
                  onPressed: c.pauseCourse,
                  icon: const Icon(
                    Icons.pause,
                    color: Colors.white70,
                    size: 20,
                  ),
                ),
              IconButton(
                tooltip: '返回点词',
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  c.stop();
                  c.select(c.index);
                },
                icon: const Icon(Icons.close, color: Colors.white70, size: 20),
              ),
            ],
          ),
          LinearProgressIndicator(
            value: ((c.coursePosition + 1) / c.courseTotal).clamp(0, 1),
            minHeight: 3,
            color: const Color(0xFFE8CF83),
            backgroundColor: Colors.white12,
          ),
          SizedBox(height: compact ? 8 : 14),
          if (c.coursePaused) ...[
            const Text(
              '已暂停',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const Text('进度已保存在此设备，麦克风已关闭。'),
            button('继续本节', () => c.playCourse()),
          ] else if (summary) ...[
            Text(
              c.vocabulary.newThisCourse.isEmpty ? '完成本课练习' : '这一课，又多认识了一些词',
              style: const TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '本课新增 +${c.vocabulary.newThisCourse.length} · 累计接触 ${c.vocabulary.seen.length} 词',
              style: const TextStyle(
                fontSize: 22,
                color: Color(0xFF91D5FF),
                fontWeight: FontWeight.bold,
              ),
            ),
            Text((c.vocabulary.newThisCourse.toList()..sort()).join(' · ')),
            const SizedBox(height: 8),
            Text('听辨与选择：${(data['correct'] as List? ?? []).length}/5 次未用提示'),
            Text(
              '词语回忆尝试：${(data['attempts'] as List? ?? []).length}/2 · 句子表达尝试：${(data['expressions'] as List? ?? []).length}',
            ),
            const Text(
              '出现过不等于掌握，复习时再看看能否听懂和说出。',
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
            button('再练一轮', () => c.playCourse(restart: true)),
          ] else ...[
            if (c.coursePicture.isNotEmpty)
              fruit(c.coursePicture, size: compact ? 42 : 60),
            if (!c.hideAnswer && c.courseDisplay.isNotEmpty)
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, .06),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: c.lessonPhase == 'phoneme'
                    ? Text(
                        '/${c.courseDisplay}/',
                        key: ValueKey('ipa:${c.courseDisplay}'),
                        style: TextStyle(
                          fontFamily: 'NotoSansIPA',
                          fontSize: compact ? 23 : 30,
                        ),
                      )
                    : LearningText(
                        c.courseDisplay,
                        key: ValueKey('${c.courseStep}:${c.courseDisplay}'),
                        controller: c,
                        size: compact ? 23 : 30,
                      ),
              ),
            if (entry != null && !c.hideAnswer)
              Text(
                '${entry.ipa}  美式',
                style: TextStyle(
                  fontFamily: 'NotoSansIPA',
                  fontFamilyFallback: ['NotoSansSC'],
                  fontSize: compact ? 15 : 18,
                  color: Colors.white70,
                ),
              ),
            const SizedBox(height: 5),
            Text(c.courseText, style: TextStyle(fontSize: compact ? 13 : 15)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 7,
              runSpacing: 6,
              children: [
                for (final option in c.courseOptions)
                  button(
                    option['label']!,
                    () => c.respondToCourse(option['id']!),
                    icon:
                        const [
                          'apple',
                          'banana',
                          'choose_apple',
                          'choose_banana',
                        ].contains(option['id'])
                        ? fruit(
                            option['id']!.replaceFirst('choose_', ''),
                            size: 35,
                          )
                        : null,
                  ),
                if (c.canCapture && !c.automaticReading && !c.automaticStarting)
                  button(
                    c.capturing ? '说完了' : '手动跟读',
                    c.processingSpeech ? null : c.toggleCapture,
                  ),
                if (['apple', 'banana'].contains(displayKey) && !c.hideAnswer)
                  button('音标参考', () => sounds(context, displayKey)),
              ],
            ),
            if (c.courseSegments.isNotEmpty) ...[
              const SizedBox(height: 7),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final segment in c.courseSegments)
                    button(
                      segment['label']!,
                      () => c.previewCourse(segment['clip']!),
                    ),
                ],
              ),
            ],
            if (c.courseOptions.isEmpty && c.speechFeedback.isEmpty)
              const Text(
                '听完后继续…',
                style: TextStyle(fontSize: 12, color: Colors.white60),
              ),
            if (c.speechFeedback.isNotEmpty)
              Text(c.speechFeedback, style: const TextStyle(fontSize: 12)),
            if (c.speechAvailable &&
                (c.canCapture ||
                    c.automaticReading ||
                    c.automaticStarting)) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  button(
                    c.automaticReading
                        ? '关闭自动跟读'
                        : c.automaticStarting
                        ? '等待麦克风…'
                        : '开启自动跟读',
                    () => c.toggleAutomatic(),
                  ),
                ],
              ),
              Text(
                c.automaticFeedback.isEmpty
                    ? '开启一次即可，说完稍停自动分析；外放时在示范后收音。'
                    : c.automaticFeedback,
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ],
            if (!c.courseOptions.any(
                  (o) => ['help', 'reveal'].contains(o['id']),
                ) &&
                !['extension_gate', 'scene_pick'].contains(c.courseStep))
              button('再听一次', c.replayLesson),
            const SizedBox(height: 5),
            const Text(
              '蓝色 = 已出现过 · 点英文单词可单独听',
              style: TextStyle(fontSize: 11, color: Color(0xFF91D5FF)),
            ),
          ],
        ],
      );
      return Padding(
        padding: EdgeInsets.symmetric(vertical: compact ? 6 : 16),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: box.maxWidth,
              child: DefaultTextStyle(
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.35,
                ),
                child: Semantics(
                  container: true,
                  explicitChildNodes: true,
                  child: content,
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
