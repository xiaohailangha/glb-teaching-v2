// American dictionary forms. Function words also have weak forms in sentences.
const courseLexicon = <String, ({String clip, String ipa, String meaning})>{
  'apple': (clip: 'apple', ipa: '/ˈæp.əl/', meaning: '苹果；两个音节，重音在前'),
  'banana': (clip: 'banana', ipa: '/bəˈnæn.ə/', meaning: '香蕉；三个音节，重音在中间'),
  'i': (clip: 'part_i', ipa: '/aɪ/', meaning: '我'),
  'want': (clip: 'part_want', ipa: '/wɑːnt/', meaning: '想要'),
  'eat': (clip: 'part_eat', ipa: '/iːt/', meaning: '吃'),
  'red': (clip: 'part_red', ipa: '/red/', meaning: '红色'),
  'a': (clip: 'word_a', ipa: '/eɪ/；弱读 /ə/', meaning: '一个；句子里通常弱读'),
  'an': (clip: 'word_an', ipa: '/æn/；弱读 /ən/', meaning: '一个；句子里通常弱读'),
  'to': (
    clip: 'word_to',
    ipa: '/tuː/；弱读 /tə/',
    meaning: '在 want to eat 中连接动作；句中可弱读',
  ),
};
