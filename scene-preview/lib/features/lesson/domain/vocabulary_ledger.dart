/// Exposure is not mastery. Only actual visible/heard learning content enters here.
class VocabularyLedger {
  final seen = <String>{}, newThisCourse = <String>{};
  bool inCourse = false;
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
    for (final word in words(text)) {
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
    seen.addAll((data['seen'] as List? ?? []).whereType<String>());
    newThisCourse.addAll((data['new'] as List? ?? []).whereType<String>());
    inCourse = data['inCourse'] == true;
  }
}
