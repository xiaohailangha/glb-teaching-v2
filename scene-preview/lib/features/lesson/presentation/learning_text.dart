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
                        milliseconds: 180 + token.start.clamp(0, 40) * 8,
                      ),
                      builder: (context, value, child) => Opacity(
                        opacity: value,
                        child: Transform.translate(
                          offset: Offset(0, 4 * (1 - value)),
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
                            color:
                                controller.vocabulary.seen.contains(
                                  token[0]!.toLowerCase(),
                                )
                                ? const Color(0xFF91D5FF)
                                : Colors.white,
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
