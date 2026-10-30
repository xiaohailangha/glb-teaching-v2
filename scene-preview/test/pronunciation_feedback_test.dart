import 'package:flutter_test/flutter_test.dart';
import 'package:snow_speaks/features/lesson/domain/pronunciation_feedback.dart';

Map result(List<Map> words, {double completion = 1, double accuracy = 90}) => {
  'Words': words,
  'PronCompletion': completion,
  'PronAccuracy': accuracy,
};
Map word(String text, {double score = 90, int tag = 0}) => {
  'Word': text,
  'PronAccuracy': score,
  'MatchTag': tag,
};
void main() {
  test('a full sentence passes only with complete matching words', () {
    final rows = [word('I'), word('want'), word('an'), word('apple')];
    expect(
      PronunciationFeedback('I want an apple.', result(rows)).passed,
      isTrue,
    );
    expect(
      PronunciationFeedback(
        'I want an apple.',
        result(rows, completion: .75),
      ).passed,
      isFalse,
    );
    expect(
      PronunciationFeedback(
        'I want an apple.',
        result(rows, accuracy: 60),
      ).passed,
      isFalse,
    );
  });
  test(
    'missing, substituted, and poor words are identified in their sentence',
    () {
      var report = PronunciationFeedback(
        'I want an apple.',
        result([
          word('I'),
          word('want', score: 32),
          word('an', tag: 2),
          word('apple'),
        ]),
      );
      expect(report.passed, isFalse);
      expect(report.words.map((w) => w.status), [
        'good',
        'practice',
        'missing',
        'good',
      ]);
      expect(report.message, contains('want'));
      expect(report.message, contains('结尾'));
      report = PronunciationFeedback(
        'I want an apple.',
        result([word('I'), word('want'), word('an'), word('apple', tag: 3)]),
      );
      expect(report.focus?.word, 'apple');
      expect(report.focus?.status, 'wrong');
    },
  );
  test('empty, extra speech, and negative scores never pass', () {
    expect(PronunciationFeedback('apple', {}).reliable, isFalse);
    expect(
      PronunciationFeedback('apple', result([word('apple', score: -1)])).passed,
      isFalse,
    );
    expect(
      PronunciationFeedback(
        'apple',
        result([word('apple'), word('*', tag: 1)]),
      ).passed,
      isFalse,
    );
  });
  test('word success cannot be mistaken for sentence success', () {
    final one = result([word('apple')]);
    expect(PronunciationFeedback('apple', one).passed, isTrue);
    expect(PronunciationFeedback('I want an apple.', one).passed, isFalse);
  });
}
