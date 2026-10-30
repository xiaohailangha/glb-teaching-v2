class Emotion {
  final String id, label, english, description;
  const Emotion(this.id, this.label, this.english, this.description);
}

const emotions = [
  Emotion('happy', '开心', 'HAPPY', '舒展眉眼，张开双臂迎接好消息。'),
  Emotion('sad', '伤心', 'SAD', '眉心抬起，低头收肩，目光慢慢落下。'),
  Emotion('frustrated', '沮丧', 'FRUSTRATED', '紧抿嘴唇，摇头摊手，无奈地放下双臂。'),
  Emotion('afraid', '害怕', 'AFRAID', '眼睛睁大，身体后缩，双手护在身前。'),
  Emotion('angry', '生气', 'ANGRY', '压低眉头，绷紧嘴角，身体前倾。'),
  Emotion('surprised', '惊讶', 'SURPRISED', '眉眼快速打开，双手抬起后停住。'),
  Emotion('curious', '好奇', 'CURIOUS', '挑眉偏头靠近，单手探询。'),
  Emotion('confused', '疑惑', 'CONFUSED', '左右看一看，歪头摊开手掌。'),
  Emotion('shy', '害羞', 'SHY', '含蓄微笑，避开目光，收起双手。'),
  Emotion('proud', '自豪', 'PROUD', '抬起下巴，挺胸，带着克制的笑意。'),
  Emotion('disgusted', '厌恶', 'DISGUSTED', '眯眼转开身体，抬手示意远离。'),
  Emotion('relieved', '释然', 'RELIEVED', '轻轻呼气，肩膀落下，笑容慢慢回来。'),
];
