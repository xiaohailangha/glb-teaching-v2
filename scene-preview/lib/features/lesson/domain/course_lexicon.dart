// American dictionary forms. Function words also have weak forms in sentences.
const courseLexicon = <String, ({String clip, String ipa, String meaning})>{
  'water': (
    clip: 'unit_water',
    ipa: '/ˈwɑː.tər/',
    meaning: '水；美式自然语流中的 t 常读成轻快的闪音',
  ),
  'milk': (clip: 'unit_milk', ipa: '/mɪlk/', meaning: '牛奶'),
  'tea': (clip: 'unit_tea', ipa: '/tiː/', meaning: '茶'),
  'coffee': (clip: 'unit_coffee', ipa: '/ˈkɑː.fi/', meaning: '咖啡'),
  'some': (clip: 'unit_some', ipa: '/sʌm/', meaning: '一些；句中可以轻读'),
  'please': (clip: 'unit_please', ipa: '/pliːz/', meaning: '请；使请求更礼貌'),
  'thank': (clip: 'unit_thank', ipa: '/θæŋk/', meaning: '感谢'),
  'you': (clip: 'unit_you', ipa: '/juː/', meaning: '你；你们'),
  'apple': (clip: 'apple', ipa: '/ˈæp.əl/', meaning: '苹果；两个音节，重音在前'),
  'banana': (clip: 'banana', ipa: '/bəˈnæn.ə/', meaning: '香蕉；三个音节，重音在中间'),
  'i': (clip: 'part_i', ipa: '/aɪ/', meaning: '我'),
  'want': (clip: 'part_want', ipa: '/wɑːnt/', meaning: '想要'),
  'eat': (clip: 'part_eat', ipa: '/iːt/', meaning: '吃'),
  'red': (clip: 'part_red', ipa: '/red/', meaning: '红色'),
  'a': (clip: 'word_a', ipa: '/ə/；强读 /eɪ/', meaning: '一个；这里示范句中弱读'),
  'an': (clip: 'word_an', ipa: '/ən/；强读 /æn/', meaning: '一个；这里示范句中弱读'),
  'to': (
    clip: 'word_to',
    ipa: '/tuː/；弱读 /tə/',
    meaning: '在 want to eat 中连接动作；句中可弱读',
  ),
};
