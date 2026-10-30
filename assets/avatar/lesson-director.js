import {curve} from './teaching-performance.js';

// Pedagogical intent chooses expression and gesture. No random emotion reel,
// and no claim about pronunciation quality without an actual learner response.
export class LessonDirector {
  constructor({word,rate=1,repeat=1,reason='start',variation=0}){
    this.word=word;this.rate=rate;this.repeat=repeat;this.variation=variation%3;
    const intro=reason==='retry'?'intro_retry':rate<1?'intro_slow':reason==='next'?'intro_next':['intro_warm','intro_listen','intro_next'][this.variation];
    this.stages=[{phase:'introduce',clip:intro,rate:1}];
    for(let i=0;i<repeat;i++)this.stages.push({phase:'demonstrate',clip:word,rate,iteration:i+1});
    this.stages.push({phase:'invite',clip:this.variation===1?'invite_two':'invite_one',rate:1},{phase:'listen',clip:null});
    this.index=0;this.reason=reason;
  }
  get stage(){return this.stages[this.index];}
  advance(){
    if(['listen','finished'].includes(this.stage.phase))return this.stage;
    this.index++;
    return this.stage||{phase:'finished',clip:null};
  }
  respond(){
    if(this.stage?.phase!=='listen')return null;
    this.stages.push({phase:'encourage',clip:this.variation===1?'encourage_two':'encourage_one',rate:1},{phase:'finished',clip:null});
    this.index++;return this.stage;
  }
}

export class PronunciationDirector {
  constructor({word,clip,kind,variation=0}){
    this.word=word;this.variation=variation%3;this.stages=[{phase:kind,clip,rate:1},{phase:'finished',clip:null}];this.index=0;
  }
  get stage(){return this.stages[this.index];}
  advance(){this.index=Math.min(1,this.index+1);return this.stage;}
  respond(){return null;}
}

export function lessonPose(phase,progress,elapsed,variation=0){
  const p=Math.max(0,Math.min(1,progress));
  const v=variation%3;
  let time=7.5,accent=0,accentTime=38;
  if(phase==='introduce'){time=1.55+1.8*p;accent=.12;accentTime=(v===1?36:0)+1.4+p;}
  if(phase==='demonstrate'){time=3.65+2.05*p;accent=v===1?.24:.12;accentTime=(v===1?36:0)+1.8+p*.6;}
  if(phase==='invite'){time=5.8+1.4*p;accent=.10;accentTime=38;}
  if(phase==='listen'){time=7.3+.8*(.5+.5*Math.sin(elapsed*.65));accent=.14;accentTime=38+.25*Math.sin(elapsed*.8);}
  if(phase==='encourage'){time=8.85+1.149*p;accent=.28*Math.sin(Math.PI*p);accentTime=1.5+p*2;}
  if(phase==='phoneme'||phase==='meaning'){time=3.7+Math.min(1.8,elapsed);accent=.12;accentTime=37.6+Math.min(.8,elapsed*.4);}
  return {time,accent,accentTime};
}

export function applyLessonFace(w,phase,progress,elapsed,variation=0){
  const p=Math.max(0,Math.min(1,progress));
  for(const name of ['HeadNod','LookLeft','LookRight','Breathe','Gesture','Warm','BrowRelax','BrowUp','Smile'])w[name]=0;
  const spoken=Math.min(1,(w.AA||0)+(w.EE||0)+(w.OO||0)+(w.UU||0)+(w.MBP||0)+.5*(w.FF||0));
  let smile=.50,eyes=.45,brow=.20,curious=.08,gaze=0;
  if(phase==='introduce'){
    gaze=curve([[0,0],[.16,.12],[.4,.75],[.68,.65],[.85,0],[1,0]],p);
    eyes=.52;brow=.18+.20*Math.sin(p*Math.PI);smile=.58;
  }
  if(['demonstrate','phoneme','meaning'].includes(phase)){
    eyes=.45;brow=.15+.22*Math.sin(p*Math.PI*2)**2;smile=.48;gaze=.035*Math.sin(elapsed*1.7);
  }
  if(phase==='invite'){eyes=.58;brow=.22;curious=.18;smile=.65;}
  if(phase==='listen'){
    eyes=.38;brow=.12;curious=.12;smile=.42;
    // Brief, small gaze shifts with a return to the learner, not endless staring.
    gaze=.065*Math.sin(elapsed*.7)*Math.sin(elapsed*.31);
  }
  if(phase==='encourage'){smile=.72+.12*Math.sin(p*Math.PI);eyes=.78;brow=.25;}
  w.SmileLeft=smile*(1-.78*spoken);w.SmileRight=w.SmileLeft*(variation===1?.86:.94);
  w.SmileEyes=eyes;w.BrowLeft=brow;w.BrowRight=brow*.65;w.Curious=curious;
  w.Attentive=phase==='listen'?.38:.18;
  w.GazeRight=Math.max(0,gaze);w.GazeLeft=Math.max(0,-gaze);w.GazeDown=0;w.GazeUp=0;
}

// Blend from the rendered pose to the new target; source clips can be remapped
// between teaching beats without snapping the shoulders or hands.
export class PoseSmoother {
  constructor(bones){this.items=bones.map(bone=>({bone,position:bone.position.clone(),quaternion:bone.quaternion.clone(),scale:bone.scale.clone()}));}
  update(dt,enabled){
    const blend=enabled?1-Math.exp(-Math.max(0,dt)*18):1;
    for(const item of this.items){
      item.position.lerp(item.bone.position,blend);item.quaternion.slerp(item.bone.quaternion,blend);item.scale.lerp(item.bone.scale,blend);
      item.bone.position.copy(item.position);item.bone.quaternion.copy(item.quaternion);item.bone.scale.copy(item.scale);
    }
  }
}
