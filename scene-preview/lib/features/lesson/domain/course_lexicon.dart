// American dictionary forms. Function words also have weak forms in sentences.
final courseLexicon = <String, ({String clip, String ipa, String meaning})>{};

/// Install vocabulary from the same immutable release as lesson and audio data.
void installCourseLexicon(Map<String, dynamic> catalog) {
  final rows = catalog['lexicon'] as List?;
  if (rows == null) return;
  final next = <String, ({String clip, String ipa, String meaning})>{};
  for (final row in rows) {
    final word = (row['word'] as String).toLowerCase();
    final clip =
        row['clip'] as String? ??
        Uri.parse(row['audio']['url'] as String).pathSegments.last
            .replaceFirst('.wav', '');
    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(clip) || next.containsKey(word)) {
      throw const FormatException('课程词库无效');
    }
    next[word] = (
      clip: clip,
      ipa: row['ipa'] as String,
      meaning: row['meaning'] as String,
    );
  }
  if (next.isEmpty) throw const FormatException('课程词库为空');
  courseLexicon
    ..clear()
    ..addAll(next);
}
