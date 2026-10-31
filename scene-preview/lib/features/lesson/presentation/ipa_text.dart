import 'package:flutter/material.dart';

import '../application/lesson_controller.dart';
import '../domain/ipa_sounds.dart';

/// Inline IPA in prose and transcriptions shares the same sound hit targets.
class IpaText extends StatelessWidget {
  const IpaText(this.text, {super.key, required this.controller, this.style});
  final String text;
  final LessonController controller;
  final TextStyle? style;
  @override
  Widget build(BuildContext context) {
    final spans = <InlineSpan>[];
    var last = 0;
    final symbols = ipaSounds.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final match in RegExp(r'/[^/\n]+/').allMatches(text)) {
      spans.add(TextSpan(text: text.substring(last, match.start)));
      final ipa = match[0]!;
      var i = 0;
      while (i < ipa.length) {
        final found = symbols.where((s) => ipa.startsWith(s, i));
        if (found.isEmpty) {
          spans.add(TextSpan(text: ipa[i++]));
        } else {
          final symbol = found.first;
          spans.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: Semantics(
                button: true,
                label: '试听音标 /$symbol/',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => controller.previewIpa(symbol),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 5,
                      horizontal: 1,
                    ),
                    child: Text(
                      symbol,
                      style: (style ?? const TextStyle()).copyWith(
                        fontFamily: 'NotoSansIPA',
                        decoration: TextDecoration.underline,
                        decorationStyle: TextDecorationStyle.dotted,
                        decorationColor: Colors.white38,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          i += symbol.length;
        }
      }
      last = match.end;
    }
    spans.add(TextSpan(text: text.substring(last)));
    return Text.rich(TextSpan(children: spans), style: style);
  }
}
