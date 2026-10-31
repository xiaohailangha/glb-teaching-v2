class WordFeedback {
  const WordFeedback(this.word, this.status, this.score, this.phone);
  final String word, status, phone;
  final double score;
  Map<String, Object> toJson() => {
    'word': word,
    'status': status,
    'score': score,
    'phone': phone,
  };
}

class PronunciationFeedback {
  PronunciationFeedback(this.target, Map result) {
    final expected = RegExp(r"[a-z]+(?:'[a-z]+)?")
        .allMatches(target.toLowerCase())
        .map((m) => m[0]!)
        .toList();
    final rows = (result['Words'] as List? ?? []).whereType<Map>().toList();
    var cursor = 0;
    for (final word in expected) {
      Map? row;
      while (cursor < rows.length) {
        final candidate = rows[cursor];
        if (candidate['MatchTag'] == 1) {
          extra = true;
          cursor++;
          continue;
        }
        final value = (candidate['Word']?.toString() ?? '')
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z\x27]'), '');
        if (value == word) {
          row = candidate;
          cursor++;
        }
        break;
      }
      final score = (row?['PronAccuracy'] as num?)?.toDouble() ?? -1;
      final tag = row?['MatchTag'];
      final status = row == null || tag == 2
          ? 'missing'
          : tag == 3
          ? 'wrong'
          : tag != 0 || score < 0
          ? 'uncertain'
          // Reduced function words are evaluated in context. Missing/wrong
          // words still fail; a recognized weak vowel need not be stressed.
          : score <
                (expected.length > 1 && const {'a', 'an', 'to'}.contains(word)
                    ? 50
                    : 65)
          ? 'practice'
          : 'good';
      final phones = (row?['PhoneInfos'] as List? ?? [])
          .whereType<Map>()
          .where(
            (p) =>
                p['PronAccuracy'] is num &&
                (p['PronAccuracy'] as num) >= 0 &&
                (p['PronAccuracy'] as num) < 60,
          )
          .toList();
      words.add(
        WordFeedback(
          word,
          status,
          score,
          phones.isEmpty ? '' : phones.first['Phone']?.toString() ?? '',
        ),
      );
    }
    if (rows.skip(cursor).any((r) => r['MatchTag'] == 1)) extra = true;
    final accuracy = (result['PronAccuracy'] as num?)?.toDouble() ?? -1;
    final completion = (result['PronCompletion'] as num?)?.toDouble() ?? 0;
    reliable = rows.isNotEmpty && accuracy >= 0 && completion >= .3;
    passed =
        reliable &&
        completion >= .98 &&
        accuracy >= 75 &&
        words.isNotEmpty &&
        words.every((w) => w.status == 'good') &&
        !extra;
  }
  final String target;
  final words = <WordFeedback>[];
  bool reliable = false, passed = false, extra = false;
  WordFeedback? get focus {
    for (final w in words) {
      if (w.status != 'good') return w;
    }
    return null;
  }

  String get message {
    if (!reliable) return '这次没听清，不算读错。靠近一点，再试一次。';
    if (passed) return '这句读好了！';
    final w = focus;
    if (w == null) return extra ? '听到多出的声音，我们再读完整句。' : '把整句连起来再试一次。';
    final lead = switch (w.status) {
      'missing' => '没听到 ${w.word}',
      'wrong' => '${w.word} 没有匹配上',
      'uncertain' => '${w.word} 还没听清',
      _ => '${w.word} 需要再练',
    };
    final sound =
        phoneNames[w.phone.replaceAll(RegExp(r'[0-9]'), '').toLowerCase()];
    return '$lead。${sound == null ? '' : '重点听 /$sound/。'}${wordGuide[w.word] ?? '先听示范，留意重音和结尾。'}';
  }
}

const wordGuide = <String, String>{
  'water': '重音在前；美式自然语流中，两个元音之间的 t 常轻快一碰，结尾保留 r 的音色。',
  'milk': '/ɪ/ 短一些，结尾 /lk/ 连起来，不额外加元音。',
  'tea': '/t/ 后接 /iː/，只有一个音节。',
  'coffee': '两个音节，重音在前；后面的 fi 轻一些。',
  'some': '结尾 /m/ 合拢双唇；在句子里可以轻读。',
  'please': '/p/ 接 /l/，结尾 /z/ 声带振动，不是 /s/。',
  'thank': '舌尖轻触上下齿之间发 /θ/；结尾 /ŋk/ 连起来。',
  'you': '/j/ 平滑接 /uː/，不要拆成两个音节。',
  'apple': '前面的 /æ/ 嘴张开、舌位靠前；后面 /əl/ 轻读。',
  'banana': '三个音节，中间 /næ/ 重读，两端 /ə/ 轻读。',
  'want': '先圆唇发 /w/，结尾保留 /nt/，不要额外加一个元音。',
  'eat': '/iː/ 嘴角展开，结尾 /t/ 短促，不要读成两个音节。',
  'red': '/r/ 舌尖不要碰上腭，/e/ 短一些，结尾是 /d/。',
  'i': '/aɪ/ 从张口滑向较小口形，一口气读完。',
  'a': '独立读 /eɪ/；放回句子时通常轻读 /ə/。',
  'an': '句子中轻读 /ən/，/n/ 自然接到 apple 的开头。',
  'to': '独立读 /tuː/；to eat 连在一起读，不必刻意停顿。',
};

const phoneNames = <String, String>{
  'ae': 'æ',
  'ah': 'ə',
  'ax': 'ə',
  'iy': 'iː',
  'ih': 'ɪ',
  'ay': 'aɪ',
  'ey': 'eɪ',
  'eh': 'e',
  'uw': 'uː',
  'n': 'n',
  'p': 'p',
  't': 't',
  'd': 'd',
  'l': 'l',
  'w': 'w',
  'r': 'ɹ',
  'b': 'b',
};
