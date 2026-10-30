import 'package:flutter_test/flutter_test.dart';
import 'package:snow_speaks/features/lesson/domain/phonetic_token.dart';
import 'package:snow_speaks/features/lesson/domain/lesson_word.dart';
import 'package:snow_speaks/features/lesson/application/lesson_controller.dart';

void main() {
  test(
    'every transcription preserves symbols and exposes complete phonemes',
    () {
      for (final word in lessonWords) {
        final tokens = phoneticTokens(word.phonetic, word.sounds);
        expect(tokens.map((t) => t.text).join(), word.phonetic);
        expect(tokens.where((t) => t.playable).map((t) => t.text), word.sounds);
        if (word.id == 'apple') {
          expect(tokens.where((t) => t.playable).map((t) => t.isVowel), [
            true,
            false,
            false,
          ]);
          expect(tokens.where((t) => t.playable).map((t) => t.text), [
            'æ',
            'p',
            'əl',
          ]);
          expect(tokens.where((t) => t.isWeakEnding).length, 1);
        }
        expect(
          tokens.where((t) => !t.playable).every((t) => '/ˈ.'.contains(t.text)),
          isTrue,
        );
      }
    },
  );
  test(
    'rapid individual clicks cancel earlier sounds and keep language routing separate',
    () {
      final c = LessonController();
      final commands = <Map<String, Object?>>[];
      c.attach(commands.add);
      c.handle({'event': 'ready'});
      c.playPhoneme('æ');
      final oldSession = c.session;
      expect(commands.last['symbol'], 'æ');
      c.playPhoneme('p');
      expect(commands.last['symbol'], 'p');
      c.handle({'event': 'ended', 'session': oldSession});
      expect(c.playing, isTrue);
      expect(c.activeSound, 'p');
      c.replayLesson();
      expect(commands.last['symbol'], 'p');
      expect(commands.last['type'], 'pronunciation');
      c.playPhoneme('əl');
      expect(commands.last['symbol'], 'əl');
      final groupedCount = commands.length;
      c.playPhoneme('ə');
      c.playPhoneme('l');
      expect(commands.length, groupedCount);
      c.playMeaning();
      expect(commands.last['kind'], 'meaning');
      expect(commands.last['word'], 'apple');
      c.play();
      expect(commands.last['type'], 'play');
      expect(c.activeSound, '');
      final count = commands.length;
      c.playPhoneme('ˈ');
      expect(commands.length, count);
      c.dispose();
    },
  );
}
