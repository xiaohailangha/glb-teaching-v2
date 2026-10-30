import 'package:flutter/material.dart';

import '../application/lesson_controller.dart';
import 'fruit_painter.dart';

class AdultCoursePanel extends StatelessWidget {
  const AdultCoursePanel({super.key, required this.controller});
  final LessonController controller;
  Widget fruit(String word, {double size = 70}) => Semantics(
    label: word == 'apple' ? '苹果图片' : '香蕉图片',
    child: CustomPaint(
      size: Size(size, size * .95),
      painter: FruitPainter(word),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final c = controller, summary = c.courseStep == 'summary';
    final data = c.courseCheckpoint ?? {};
    final taught = (data['taught'] as List? ?? []).length;
    final correct = (data['correct'] as List? ?? []).length;
    final attempts = (data['attempts'] as List? ?? []).length;
    Widget button(String label, VoidCallback? action, {Widget? icon}) =>
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: Colors.white12,
            minimumSize: const Size(48, 44),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          onPressed: action,
          child: icon == null
              ? Text(label)
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [icon, Text(label)],
                ),
        );
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(0, 36, 0, 60),
      child: DefaultTextStyle(
        style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.45),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '成人零基础 · ${c.courseChapter}',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: (c.coursePosition + 1) / c.courseTotal,
              backgroundColor: Colors.white12,
              color: const Color(0xFFE8CF83),
              minHeight: 3,
            ),
            const SizedBox(height: 12),
            if (c.coursePaused) ...[
              const Text(
                '已暂停',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const Text('学习位置已保存在此设备。准备好后接着学。'),
              const SizedBox(height: 12),
              button('继续本节', () => c.playCourse()),
            ] else ...[
              if (c.coursePicture.isNotEmpty) fruit(c.coursePicture),
              if (!c.hideAnswer && c.courseDisplay.isNotEmpty)
                Text(
                  c.courseDisplay,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              const SizedBox(height: 8),
              Text(c.courseText),
              if (summary) ...[
                const SizedBox(height: 12),
                Text('正式学过：$taught / 2 个词'),
                Text('未用提示的听辨与选择：$correct / 5 次'),
                Text('主动尝试回忆：$attempts / 2 个词'),
                const Text(
                  '这是一轮练习记录，不代表已经掌握。',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 12),
                button('再练一轮', () => c.playCourse(restart: true)),
              ] else ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final option in c.courseOptions)
                      button(
                        option['label']!,
                        () => c.respondToCourse(option['id']!),
                        icon: const ['apple', 'banana'].contains(option['id'])
                            ? fruit(option['id']!, size: 55)
                            : null,
                      ),
                  ],
                ),
                if (c.courseOptions.isEmpty && c.speechFeedback.isEmpty)
                  const Text(
                    '听完后继续…',
                    style: TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                if (c.canCapture) ...[
                  const SizedBox(height: 10),
                  button(
                    c.capturing
                        ? '说完了'
                        : c.processingSpeech
                        ? '处理中…'
                        : c.lessonPhase == 'recall'
                        ? '说出答案'
                        : '跟读',
                    c.processingSpeech || c.captureState == 'starting'
                        ? null
                        : c.toggleCapture,
                  ),
                ],
                if (c.speechFeedback.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(c.speechFeedback),
                  ),
                if (c.lessonPhase == 'listen' && c.courseOptions.isNotEmpty)
                  Wrap(
                    spacing: 5,
                    children: [
                      for (final sound in c.word.sounds.toSet())
                        TextButton(
                          onPressed: () => c.previewCourse(
                            sound == 'əl'
                                ? 'group_schwa_l'
                                : {
                                    'æ': 'phoneme_ae',
                                    'p': 'phoneme_p',
                                    'b': 'phoneme_b',
                                    'ə': 'phoneme_schwa',
                                    'n': 'phoneme_n',
                                  }[sound]!,
                          ),
                          child: Text(
                            '/$sound/',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ),
                    ],
                  ),
              ],
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (!c.coursePaused &&
                    !summary &&
                    !c.courseOptions.any((o) => o['id'] == 'help'))
                  button('再听一次', c.replayLesson),
                if (!c.coursePaused && !summary) button('暂停', c.pauseCourse),
                button('返回点词', () {
                  c.stop();
                  c.select(c.index);
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
