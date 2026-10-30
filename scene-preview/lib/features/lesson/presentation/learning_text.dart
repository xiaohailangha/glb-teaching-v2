import 'package:flutter/material.dart';

import '../application/lesson_controller.dart';
import '../domain/course_lexicon.dart';

class LearningText extends StatelessWidget {
  const LearningText(
    this.text, {
    super.key,
    required this.controller,
    this.size = 30,
  });
  final String text;
  final LessonController controller;
  final double size;
  String status(String word) {
    for (final row in controller.wordFeedback) {
      if (row['word'] == word.toLowerCase()) {
        return row['status']?.toString() ?? '';
      }
    }
    return '';
  }

  Color color(String word) {
    final value = status(word);
    if (value == 'good') return const Color(0xFFBDE5DD);
    if (value.isNotEmpty) return const Color(0xFFFFCB95);
    return controller.vocabulary.seen.contains(word.toLowerCase())
        ? const Color(0xFFADD6E4)
        : Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = RegExp(r"[A-Za-z]+(?:'[A-Za-z]+)?|[^A-Za-z]+")
        .allMatches(text);
    return Text.rich(
      TextSpan(
        children: [
          for (final token in tokens)
            if (RegExp(r'^[A-Za-z]').hasMatch(token[0]!))
              WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: Semantics(
                  button: courseLexicon.containsKey(token[0]!.toLowerCase()),
                  label: '单词 ${token[0]}',
                  child: InkWell(
                    onTap: () => controller.previewWord(token[0]!),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: Duration(
                        milliseconds: 480 + token.start.clamp(0, 40) * 12,
                      ),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) => Opacity(
                        opacity: value,
                        child: Transform.translate(
                          offset: Offset(0, 14 * (1 - value)),
                          child: child,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Text(
                          token[0]!,
                          style: TextStyle(
                            fontSize: size,
                            fontWeight: FontWeight.bold,
                            color: color(token[0]!),
                            decoration:
                                status(token[0]!).isNotEmpty &&
                                    status(token[0]!) != 'good'
                                ? TextDecoration.underline
                                : TextDecoration.none,
                            decorationStyle: TextDecorationStyle.wavy,
                            decorationColor: const Color(0xFFFFCB95),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              )
            else
              TextSpan(text: token[0]),
        ],
      ),
      style: TextStyle(
        fontSize: size,
        color: Colors.white,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}
