// Authored acting beats. Audio.currentTime is the only performance clock;
// a frame-rate drop or buffered audio cannot make the lips drift from speech.
export const PERFORMANCE_SECONDS=10;
export function curve(keys,t){
  if(t<=keys[0][0])return keys[0][1];
  for(let i=1;i<keys.length;i++){
    if(t<=keys[i][0]){const [a,x]=keys[i-1],[b,y]=keys[i];let u=(t-a)/(b-a);u=u*u*(3-2*u);return x+(y-x)*u;}
  }
  return keys[keys.length-1][1];
}
const tracks={
  // Eye shifts lead the head turn; brief returns to the learner prevent staring.
  gaze:[[0,.08],[.23,-.04],[1.45,-.04],[1.60,.82],[2.55,.68],[2.72,-.28],[3.3,-.08],[4.1,-.05],[4.65,.10],[5.1,.02],[5.85,.18],[6.1,-.08],[7.35,-.12],[7.48,.04],[8.15,.04],[8.28,-.07],[9.5,-.03],[10,.08]],
  down:[[0,.05],[.5,0],[1.5,0],[1.7,.12],[2.5,.10],[2.9,0],[6.5,0],[7.7,.06],[8.05,0],[10,.05]],
  warm:[[0,.32],[.45,.72],[1.25,.9],[1.8,.25],[2.8,.3],[3.65,.6],[4.3,.25],[5.5,.85],[6.3,.35],[7.2,.45],[8.5,.55],[9.45,.95],[10,.32]],
  curious:[[0,.04],[1.3,.08],[1.8,.16],[2.6,.10],[3.3,.03],[5.2,.10],[6.7,.6],[8.35,.5],[9.3,.08],[10,.04]],
  left:[[0,.18],[.45,.70],[1.25,.22],[2.1,.55],[3.1,.20],[4.38,.65],[4.8,.18],[5.5,.15],[6.45,.55],[7.5,.25],[8.3,.22],[9.35,.30],[10,.18]],
  right:[[0,.10],[.58,.48],[1.4,.12],[2.3,.32],[3.2,.15],[4.48,.45],[5.1,.12],[6.4,.18],[8,.12],[9.45,.22],[10,.10]],
  smile:[[0,.45],[.55,.80],[1.35,.95],[1.85,.45],[2.85,.4],[3.65,.7],[4.35,.42],[5.5,.92],[6.25,.50],[7.15,.72],[8.3,.64],[9.45,1],[10,.45]],
};
const blinks=[1.62,2.81,5.70,8.35];
export function applyPerformanceFace(weights,time){
  const t=Math.max(0,Math.min(PERFORMANCE_SECONDS,time));
  const gaze=curve(tracks.gaze,t),down=curve(tracks.down,t);
  weights.GazeRight=Math.max(0,gaze);weights.GazeLeft=Math.max(0,-gaze);
  weights.GazeDown=down;weights.GazeUp=0;
  weights.HeadNod=0;weights.LookRight=0;weights.LookLeft=0;weights.Gesture=0;weights.Breathe=0;
  weights.BrowUp=0;weights.BrowRelax=0;weights.Smile=0;
  weights.Warm=0;weights.SmileEyes=curve(tracks.warm,t);weights.Curious=curve(tracks.curious,t);
  weights.Attentive=curve([[0,.1],[.5,.32],[1.3,.05],[2.2,.18],[3.4,.05],[4.4,.3],[5.5,0],[6.6,.15],[8.2,.08],[9.4,0],[10,.1]],t);
  weights.BrowLeft=curve(tracks.left,t);weights.BrowRight=curve(tracks.right,t);
  // The emotion remains present during speech. Only incompatible mouth
  // geometry is blended to keep lips and teeth from intersecting.
  const articulation=mouthArticulation(weights);
  const smile=curve(tracks.smile,t)*(1-.7*articulation);
  weights.SmileLeft=smile;weights.SmileRight=smile*.90;
  let blink=0;
  for(const start of blinks){const d=t-start;if(d>=0&&d<.23)blink=Math.max(blink,d<.07?curve([[0,0],[.07,1]],d):d<.095?1:curve([[.095,1],[.23,0]],d));}
  weights.Blink=blink;
  return t<1.65?'greeting':t<3.65?'introducing':t<5.8?'demonstrating':t<7.1?'inviting':'listening';
}
export function clearPerformanceFace(weights){
  for(const name of ['GazeRight','GazeLeft','GazeUp','GazeDown','Warm','Curious','BrowLeft','BrowRight','SmileLeft','SmileRight','SmileEyes','Attentive'])weights[name]=0;
}

export function applyIdleFace(weights){
  weights.Smile=0;weights.BrowRelax=0;weights.BrowUp=0;
  const articulation=mouthArticulation(weights);
  weights.SmileLeft=.38*(1-.7*articulation);weights.SmileRight=.33*(1-.7*articulation);
  weights.SmileEyes=.28;weights.BrowLeft=.12;weights.BrowRight=.07;
}

function mouthArticulation(w){
  // EE already widens the corners. Counting it avoids doubling that motion
  // with an emotional smile and pushing the lips through the teeth.
  return Math.min(1,(w.AA||0)+(w.EE||0)+(w.OO||0)+(w.UU||0)+(w.MBP||0)+.5*(w.FF||0)+.5*(w.TH||0)+.3*(w.L||0));
}
