import 'package:flutter/material.dart';

import '../application/lesson_controller.dart';
import '../domain/ipa_sounds.dart';

/// Color and spacing identify complete sound units; diphthongs stay intact.
class IpaText extends StatelessWidget {
  const IpaText(
    this.text, {
    super.key,
    required this.controller,
    this.style,
    this.highlight,
    this.compact = false,
    this.minimumTargetHeight,
  });
  final String? highlight;
  final bool compact;
  final double? minimumTargetHeight;
  final String text;
  final LessonController controller;
  final TextStyle? style;
  static const colors = [
    Color(0xFFFFD19B),
    Color(0xFFAADBE9),
    Color(0xFFD0BDF4),
    Color(0xFFBDE5CC),
  ];
  @override
  Widget build(BuildContext context) {
    final spans = <InlineSpan>[];
    var last = 0, group = 0;
    final symbols = {
      ...ipaSounds.keys,
      'tʃ',
      'dʒ',
      'aʊ',
      'ɔɪ',
      'ɜːr',
      'ər',
    }.toList()..sort((a, b) => b.length.compareTo(a.length));
    for (final match in RegExp(r'/[^/\n]+/').allMatches(text)) {
      spans.add(TextSpan(text: text.substring(last, match.start)));
      final ipa = match[0]!;
      var i = 0;
      while (i < ipa.length) {
        final found = symbols.where((s) => ipa.startsWith(s, i));
        if (found.isEmpty) {
          spans.add(TextSpan(text: ipa[i++]));
          continue;
        }
        final symbol = found.first, playable = ipaSounds.containsKey(symbol);
        final color = compact && highlight == null
            ? const Color(0xFFBED1CF)
            : colors[group++ % colors.length];
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? .5 : 1.5,
                vertical: compact ? 0 : 2,
              ),
              child: Semantics(
                button: playable,
                label: playable ? '试听音标 /$symbol/' : '音标 /$symbol/',
                child: InkWell(
                  onTap: playable ? () => controller.previewIpa(symbol) : null,
                  borderRadius: BorderRadius.circular(7),
                  child: Container(
                    constraints: BoxConstraints(minHeight: minimumTargetHeight ?? (compact ? 0 : 44)),
                    child: Center(
                      widthFactor: 1,
                      heightFactor: 1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: color.withValues(
                            alpha: symbol == highlight ? .35 : .09,
                          ),
                          border: symbol == highlight
                              ? Border.all(color: color)
                              : null,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: compact ? 1.5 : 3,
                            vertical: 1,
                          ),
                          child: Text(
                            symbol,
                            style: (style ?? DefaultTextStyle.of(context).style)
                                .copyWith(
                                  fontFamily: 'NotoSansIPA',
                                  color: playable ? color : Colors.white70,
                                  height: 1.15,
                                  decoration: TextDecoration.none,
                                ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        spans.add(const TextSpan(text: '\u200b'));
        i += symbol.length;
      }
      last = match.end;
    }
    spans.add(TextSpan(text: text.substring(last)));
    return Text.rich(
      TextSpan(children: spans),
      style: style?.copyWith(height: 1.3),
    );
  }
}
