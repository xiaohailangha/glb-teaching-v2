class Stage {
  const Stage(
    this.phase, {
    this.id = '',
    this.clip,
    this.text = '',
    this.symbol = '',
    this.rate = 1,
    this.options = const [],
    this.iteration = 1,
    this.wordId = '',
    this.display = '',
    this.picture = '',
    this.chapter = '',
    this.answer = '',
    this.hide = false,
    this.practiceClip = '',
    this.speechText = '',
    this.segments = const [],
  });
  final String phase, id, text, symbol;
  final String wordId, display, picture, chapter, answer;
  final String practiceClip, speechText;
  final List<Map<String, String>> segments;
  final bool hide;
  final String? clip;
  final double rate;
  final int iteration;
  final List<Map<String, String>> options;
  bool get waiting => options.isNotEmpty || clip == null;
  bool get hideAnswer => hide || phase == 'choice' || phase == 'recall';
}

class TeachingDirector {
  TeachingDirector({
    required String word,
    this.style = 'adult',
    this.variation = 0,
    this.course = false,
    List<Stage>? stages,
    // Keep the public constructor name while resolving the active stage's word.
    // ignore: prefer_initializing_formals
  }) : _word = word,
       stages = stages ?? [];
  final String _word, style;
  String get word => stage.wordId.isEmpty ? _word : stage.wordId;
  bool fruitCourse = false;
  final taught = <String>{},
      attempts = <String>{},
      correct = <String>{},
      helped = <String>{},
      expressions = <String>{};
  Map<String, dynamic> get checkpoint => {
    'version': 1,
    'courseId': 'adult-fruit-v2',
    'expressions': expressions.toList(),
    'index': index,
    'taught': taught.toList(),
    'attempts': attempts.toList(),
    'correct': correct.toList(),
    'helped': helped.toList(),
  };
  final int variation;
  final bool course;
  final List<Stage> stages;
  int index = 0;
  List<Stage> branch = [];
  bool navigate(int direction) {
    if (!fruitCourse || stages.isEmpty) return false;
    bool practice(Stage s) =>
        s.clip == null &&
        const {'listen', 'recall', 'choice', 'finish'}.contains(s.phase);
    var current = index;
    while (current < stages.length - 1 && !practice(stages[current])) {
      current++;
    }
    int next;
    if (direction > 0) {
      if (stages[current].id == 'summary') return false;
      next = stages[current].id.startsWith('scene_')
          ? stages.indexWhere((s) => s.id == 'extension_gate')
          : current + 1;
    } else {
      next = current - 1;
      while (next >= 0 && !practice(stages[next])) {
        next--;
      }
      if (next < 0) {
        next = 0;
      }
      // The unchosen scene alternative is never a previous exercise.
      if (stages[next].id == 'scene_banana' ||
          stages[next].id == 'scene_apple') {
        next = stages.indexWhere((s) => s.id == 'scene_pick');
      }
      if (next > 0 &&
          (stages[next - 1].phase == 'demonstrate' ||
              stages[next - 1].id.endsWith('_cue'))) {
        next--;
      }
    }
    if (next < 0 || next >= stages.length) return false;
    branch = [];
    index = next;
    // Navigation is never a successful attempt or a correct answer.
    return true;
  }

  Stage get stage => branch.isNotEmpty
      ? branch.first
      : index < stages.length
      ? stages[index]
      : const Stage('finished');
  Stage advance() {
    if (fruitCourse &&
        branch.isEmpty &&
        stage.phase == 'demonstrate' &&
        !stage.hideAnswer) {
      taught.add(word);
    }
    if (stage.options.isNotEmpty ||
        stage.phase == 'finished' ||
        stage.phase == 'listen' && !course) {
      return stage;
    }
    if (branch.isNotEmpty) {
      branch.removeAt(0);
    } else {
      index++;
    }
    return stage;
  }

  Stage? respond(String action) {
    if (!course) {
      if (stage.phase != 'listen') return null;
      stages.addAll([
        Stage(
          'encourage',
          clip: variation == 1 ? 'encourage_two' : 'encourage_one',
        ),
        const Stage('finished'),
      ]);
      index++;
      return stage;
    }
    if (!stage.options.any((item) => item['id'] == action)) return null;
    if (fruitCourse) {
      final current = stage;
      if (action == 'choose_apple' || action == 'choose_banana') {
        index = stages.indexWhere(
          (s) => s.id == 'scene_${action.substring(7)}',
        );
        return stage;
      }
      if (action == 'skip' && current.id == 'extension_gate') {
        index = stages.indexWhere((s) => s.id == 'summary');
        return stage;
      }
      if (action == 'help' ||
          action == 'reveal' ||
          action == 'sound' ||
          current.answer.isNotEmpty && action != current.answer) {
        helped.add(current.id);
        final sound = action == 'sound';
        branch = [
          Stage(
            sound ? 'phoneme' : 'support',
            id: 'help_${current.id}',
            wordId: word,
            chapter: current.chapter,
            clip: sound
                ? 'phoneme_ae'
                : current.practiceClip.isNotEmpty
                ? current.practiceClip
                : current.answer.startsWith('phrase_')
                ? current.answer
                : word,
            display: sound
                ? '/æ/'
                : current.speechText.isNotEmpty
                ? current.speechText
                : current.answer == 'phrase_apple'
                ? 'an apple'
                : current.answer == 'phrase_banana'
                ? 'a banana'
                : word,
            picture: current.picture,
            text: sound
                ? '嘴张开，先听 /æ/。再回到完整单词。'
                : current.answer.isNotEmpty && action != 'help'
                ? '再听一次，留意声音对应的意思。'
                : '先听示范，再试一次。',
          ),
        ];
        return stage;
      }
      if (current.answer.isNotEmpty && !helped.contains(current.id)) {
        correct.add(current.id);
      }
      if (action == 'attempt') {
        if (current.speechText.contains(' ')) {
          expressions.add(current.id);
        } else {
          attempts.add(word);
        }
      }
      if (current.id.startsWith('scene_') && action == 'attempt') {
        index = stages.indexWhere((s) => s.id == 'extension_gate');
      } else {
        index++;
      }
      if (current.answer.isNotEmpty) {
        branch = [
          Stage(
            'success',
            id: 'feedback_${current.id}',
            wordId: current.wordId,
            chapter: current.chapter,
            clip: 'fruit_correct',
            display: current.display,
            picture: current.wordId,
            text: helped.contains(current.id)
                ? '这次选对了。稍后再试一次。'
                : '听出来了！换一个再试试。',
          ),
        ];
      }
      return stage;
    }
    if (action == 'help' || stage.phase == 'choice' && action == 'banana') {
      branch = [
        const Stage(
          'support',
          id: 'support',
          clip: 'course_support',
          text: '一起再听一次。',
        ),
        const Stage(
          'demonstrate',
          id: 'help_word',
          clip: 'apple',
          text: 'apple',
        ),
      ];
      return stage;
    }
    final choice = stage.phase == 'choice';
    index++;
    branch = [
      Stage(
        choice ? 'success' : 'encourage',
        clip: choice ? 'course_correct' : 'course_attempt',
        text: choice ? '选对了，这是苹果。' : '谢谢你的尝试。',
      ),
    ];
    return stage;
  }

  factory TeachingDirector.fruit(
    List<dynamic> rows, {
    double rate = 1,
    Map<String, dynamic>? saved,
  }) {
    final d = TeachingDirector(
      word: 'apple',
      course: true,
      stages: [
        for (final raw in rows)
          Stage(
            raw['phase'] as String,
            id: raw['id'] as String,
            wordId: raw['word'] as String? ?? 'apple',
            clip: raw['clip'] as String?,
            display: raw['display'] as String? ?? '',
            picture: raw['picture'] as String? ?? '',
            chapter: raw['chapter'] as String? ?? '',
            answer: raw['answer'] as String? ?? '',
            hide: raw['hide'] == true,
            practiceClip: raw['practiceClip'] as String? ?? '',
            speechText: raw['speechText'] as String? ?? '',
            segments: [
              for (final o in raw['segments'] as List? ?? [])
                Map<String, String>.from(o as Map),
            ],
            text: raw['text'] as String? ?? '',
            rate: rate,
            options: [
              for (final o in raw['options'] as List? ?? [])
                Map<String, String>.from(o as Map),
            ],
          ),
      ],
    )..fruitCourse = true;
    if (saved?['version'] == 1 && saved?['courseId'] == 'adult-fruit-v2') {
      d.index = ((saved?['index'] as num?)?.toInt() ?? 0).clamp(
        0,
        d.stages.length - 1,
      );
      for (final pair in [
        (d.taught, 'taught'),
        (d.attempts, 'attempts'),
        (d.correct, 'correct'),
        (d.helped, 'helped'),
        (d.expressions, 'expressions'),
      ]) {
        pair.$1.addAll((saved?[pair.$2] as List? ?? []).whereType<String>());
      }
    }
    return d;
  }

  factory TeachingDirector.word({
    required String word,
    double rate = 1,
    int repeat = 1,
    String reason = 'start',
    int variation = 0,
  }) {
    return TeachingDirector(
      word: word,
      variation: variation,
      stages: [
        for (var i = 0; i < repeat; i++)
          Stage('demonstrate', clip: word, rate: rate, iteration: i + 1),
        const Stage('listen'),
      ],
    );
  }
  factory TeachingDirector.pronunciation({
    required String word,
    required String kind,
    required String clip,
    String symbol = '',
  }) => TeachingDirector(
    word: word,
    stages: [
      Stage(kind, clip: clip, symbol: symbol),
      const Stage('finished'),
    ],
  );
  factory TeachingDirector.apple({
    required String style,
    double rate = 1,
    int variation = 0,
  }) {
    final child = style.startsWith('child');
    return TeachingDirector(
      word: 'apple',
      style: style,
      variation: variation,
      course: true,
      stages: [
        Stage(
          'introduce',
          id: 'welcome',
          clip: child ? 'course_child_intro' : 'course_intro',
          text: child ? '一起认识一个水果。' : '先认识声音，再练习读音和回忆。',
        ),
        const Stage(
          'meaning',
          id: 'meaning',
          clip: 'meaning_apple',
          text: '苹果',
        ),
        Stage(
          'demonstrate',
          id: 'whole',
          clip: 'apple',
          text: '先听完整的单词。',
          rate: rate,
        ),
        Stage(
          'explain',
          id: 'explain',
          clip: child ? 'course_child_sound' : 'course_sound',
          text: child ? '听这个声音，再一起试一试。' : '嘴张开，听 /æ/，再把声音放回单词。',
          symbol: 'æ',
        ),
        Stage(
          'phoneme',
          id: 'sound',
          clip: 'phoneme_ae',
          text: '/æ/',
          symbol: 'æ',
          rate: rate,
        ),
        Stage(
          'demonstrate',
          id: 'blend',
          clip: 'apple',
          text: '再听完整读音。',
          rate: rate,
        ),
        const Stage(
          'invite',
          id: 'ask',
          clip: 'course_choice',
          text: '听到的单词是什么意思？',
        ),
        const Stage(
          'choice',
          id: 'choice',
          text: '刚才听到的是什么？',
          options: [
            {'id': 'apple', 'label': '苹果'},
            {'id': 'banana', 'label': '香蕉'},
            {'id': 'help', 'label': '再听一次'},
          ],
        ),
        Stage(
          'invite',
          id: 'recall_prompt',
          clip: child ? 'course_child_recall' : 'course_recall',
          text: child ? '看图片，试着说出它的英文。' : '看含义，试着想起并说出英文。',
        ),
        const Stage(
          'recall',
          id: 'recall',
          text: '苹果',
          options: [
            {'id': 'attempt', 'label': '我试过了'},
            {'id': 'help', 'label': '想不起来'},
          ],
        ),
        const Stage(
          'transfer',
          id: 'transfer',
          clip: 'course_transfer',
          text: '回到完整单词，听过后再读一遍。',
        ),
        Stage(
          'demonstrate',
          id: 'final_word',
          clip: 'apple',
          text: 'apple',
          rate: rate,
        ),
        const Stage(
          'listen',
          id: 'listen',
          text: '轮到你了。',
          options: [
            {'id': 'attempt', 'label': '我读好了'},
            {'id': 'help', 'label': '再听一次'},
          ],
        ),
        const Stage(
          'finish',
          id: 'close',
          clip: 'course_finish',
          text: '今天的尝试完成了，下次再检查是否记得。',
        ),
        const Stage('finished'),
      ],
    );
  }
}
