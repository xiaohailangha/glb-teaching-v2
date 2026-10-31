/// Exposure is not mastery. Only actual visible/heard learning content enters here.
class VocabularyLedger {
  final seen = <String>{}, newThisCourse = <String>{};
  bool inCourse = false;
  // Inflected forms are taught separately but do not inflate vocabulary size.
  static String lemma(String word) => switch (word.toLowerCase()) {
    'apples' => 'apple',
    'bananas' => 'banana',
    final value => value,
  };
  bool hasSeen(String word) => seen.contains(lemma(word));
  static Iterable<String> words(String text) =>
      RegExp(r"[A-Za-z]+(?:'[A-Za-z]+)?")
          .allMatches(text)
          .map((m) => m[0]!.toLowerCase());
  void begin({bool restart = false}) {
    if (restart) newThisCourse.clear();
    inCourse = true;
  }

  bool expose(String text) {
    var changed = false;
    for (final word in words(text).map(lemma)) {
      if (seen.add(word)) {
        changed = true;
        if (inCourse) newThisCourse.add(word);
      }
    }
    return changed;
  }

  Map<String, dynamic> toJson() => {
    'seen': seen.toList(),
    'new': newThisCourse.toList(),
    'inCourse': inCourse,
  };
  void restore(Map data) {
    seen.addAll((data['seen'] as List? ?? []).whereType<String>().map(lemma));
    newThisCourse.addAll(
      (data['new'] as List? ?? []).whereType<String>().map(lemma),
    );
    inCourse = data['inCourse'] == true;
  }
}
