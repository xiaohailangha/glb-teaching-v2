class PhoneticToken {
  final String text;
  final bool playable;
  const PhoneticToken(this.text, this.playable);
  bool get isWeakEnding => text == 'əl';
  bool get isVowel =>
      const {'æ', 'ə', 'ɔ', 'ɪ', 'uː', 'ʌ', 'ʊ', 'oʊ'}.contains(text);
}

/// Match full diphthongs and length-marked vowels before individual characters;
/// slashes, syllable boundaries and stress marks are display-only.
List<PhoneticToken> phoneticTokens(String transcription, List<String> sounds) {
  final sorted = sounds.toSet().toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  final result = <PhoneticToken>[];
  var index = 0;
  while (index < transcription.length) {
    String? match;
    for (final sound in sorted) {
      if (transcription.startsWith(sound, index)) {
        match = sound;
        break;
      }
    }
    if (match != null) {
      result.add(PhoneticToken(match, true));
      index += match.length;
    } else {
      result.add(PhoneticToken(transcription[index], false));
      index++;
    }
  }
  return result;
}
