import {curve} from './teaching-performance.js';
export const EMOTION_SECONDS=6;
export const emotionIds=['happy','sad','frustrated','afraid','angry','surprised','curious','confused','shy','proud','disgusted','relieved'];
export const emotionLabels=['开心','伤心','沮丧','害怕','生气','惊讶','好奇','疑惑','害羞','自豪','厌恶','释然'];
const smooth=x=>{x=Math.max(0,Math.min(1,x));return x*x*(3-2*x);};
export function emotionEnvelope(id,t){
  return smooth(t/(['afraid','surprised'].includes(id)?.55:1.15))*(1-smooth((t-4.65)/1.35));
}
export function applyEmotionFace(weights,id,time){
  for(const name in weights)weights[name]=0;
  const t=Math.max(0,Math.min(6,time)),strength=emotionEnvelope(id,t);
  weights['Emotion_'+id]=strength;
  const blinkAt=id==='afraid'||id==='surprised'?3.5:2.8;
  const blink=curve([[0,0],[blinkAt,0],[blinkAt+.07,1],[blinkAt+.1,1],[blinkAt+.25,0],[6,0]],t);
  weights['EmotionBlink_'+id]=blink*strength;
  weights.Blink=blink*(1-strength);
  const down={sad:.65,frustrated:.2,shy:.45,relieved:.08}[id]||0;
  weights.GazeDown=down*strength;
  const scan={afraid:.32,curious:.26,confused:.38,shy:.45,disgusted:.5}[id]||0;
  const gaze=scan*strength*curve([[0,0],[.8,1],[2,1],[2.4,-.65],[3.5,-.65],[4.2,.2],[6,0]],t);
  weights.GazeRight=Math.max(0,gaze);weights.GazeLeft=Math.max(0,-gaze);
}
