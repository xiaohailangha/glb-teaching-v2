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
  });
  final String phase, id, text, symbol;
  final String? clip;
  final double rate;
  final int iteration;
  final List<Map<String, String>> options;
  bool get waiting => options.isNotEmpty || clip == null;
  bool get hideAnswer => phase == 'choice' || phase == 'recall';
}

class TeachingDirector {
  TeachingDirector({
    required this.word,
    this.style = 'adult',
    this.variation = 0,
    this.course = false,
    List<Stage>? stages,
  }) : stages = stages ?? [];
  final String word, style;
  final int variation;
  final bool course;
  final List<Stage> stages;
  int index = 0;
  List<Stage> branch = [];
  Stage get stage => branch.isNotEmpty
      ? branch.first
      : index < stages.length
      ? stages[index]
      : const Stage('finished');
  Stage advance() {
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
