import {lessonPose,applyLessonFace} from './lesson-director.js';

// Shared by normal word teaching and authored course activities. These are
// acting intentions, not inferred learner emotions or pronunciation scores.
export const learnerStyles={
  adult:{energy:1,smile:1,gaze:1},
  child46:{energy:1.2,smile:1.15,gaze:1.08},
  child79:{energy:1.1,smile:1.07,gaze:1.04},
  child1012:{energy:1.02,smile:1.02,gaze:1},
  correction:{energy:1,smile:.94,gaze:1},
};
export const teachingIntent={
  introduce:'welcome',meaning:'discover',explain:'explain',demonstrate:'model',phoneme:'model',
  invite:'invite',listen:'listen',choice:'recall',recall:'recall',
  support:'support',success:'confirm',encourage:'acknowledge',transfer:'transfer',finish:'close',
};
export const actingRules={
  welcome:{emotion:'warm',gaze:'learner-content-learner',gesture:'open-hand'},
  discover:{emotion:'curious',gaze:'content-learner',gesture:'present'},
  explain:{emotion:'focused',gaze:'content-learner',gesture:'explanatory-beat'},
  model:{emotion:'engaged',gaze:'learner',gesture:'natural-speech'},
  invite:{emotion:'inviting',gaze:'learner',gesture:'offer-turn'},
  listen:{emotion:'attentive',gaze:'learner',gesture:'receptive'},
  recall:{emotion:'patient',gaze:'learner',gesture:'receptive'},
  support:{emotion:'reassuring',gaze:'learner-content',gesture:'offer-help'},
  confirm:{emotion:'pleased',gaze:'learner',gesture:'small-acknowledgement'},
  acknowledge:{emotion:'warm',gaze:'learner',gesture:'thank-attempt'},
  transfer:{emotion:'curious',gaze:'content-learner',gesture:'present'},
  close:{emotion:'warm',gaze:'learner',gesture:'settle'},
};
const clamp=x=>Math.max(0,Math.min(1,Number.isFinite(x)?x:0));
const faceNames=['SmileLeft','SmileRight','SmileEyes','BrowLeft','BrowRight','Curious','Attentive','GazeRight','GazeLeft','GazeUp','GazeDown'];

export function coursePose(phase,p,elapsed,variation=0,style='adult'){
  const intent=teachingIntent[phase]||'listen',profile=learnerStyles[style]||learnerStyles.adult;
  const basePhase={welcome:'introduce',discover:'introduce',explain:'demonstrate',model:'demonstrate',invite:'invite',listen:'listen',recall:'listen',support:'invite',confirm:'encourage',acknowledge:'encourage',transfer:'introduce',close:'listen'}[intent];
  const pose=lessonPose(basePhase,clamp(p),elapsed,variation);
  const beat=Math.sin(Math.PI*clamp(p));
  // Full speaking gestures remain available during articulation. Modulate
  // meaning/energy; never freeze the body merely because a sound is taught.
  if(['discover','explain','transfer'].includes(intent)){
    pose.accent=.22+.12*beat;pose.accentTime=36+1.2+clamp(p)*2.6;
  }else if(intent==='support'){
    pose.accent=.24;pose.accentTime=66+1.2+clamp(p)*2.5;
  }else if(intent==='confirm'){
    pose.accent=.22+.15*beat;pose.accentTime=1.1+clamp(p)*3;
  }else if(intent==='listen'||intent==='recall'){
    // Bounded, nonrepeating breathing/posture beats; no escalating impatience.
    pose.time=7.45+.3*Math.sin(elapsed*.52)+.12*Math.sin(elapsed*.21);
    pose.accent=.14;pose.accentTime=37.6+.3*Math.sin(elapsed*.35);
  }
  pose.accent=Math.min(.48,pose.accent*profile.energy);
  return pose;
}

export function applyCourseFace(w,phase,p,elapsed,variation=0,style='adult'){
  const intent=teachingIntent[phase]||'listen',profile=learnerStyles[style]||learnerStyles.adult;
  const basePhase={welcome:'introduce',discover:'introduce',explain:'demonstrate',model:'demonstrate',invite:'invite',listen:'listen',recall:'listen',support:'listen',confirm:'encourage',acknowledge:'encourage',transfer:'introduce',close:'listen'}[intent];
  applyLessonFace(w,basePhase,clamp(p),elapsed,variation);
  const pulse=Math.sin(Math.PI*clamp(p)),micro=Math.sin(elapsed*1.7+variation)*.025;
  if(['discover','explain','transfer'].includes(intent)){
    w.Curious=.22+.14*pulse;w.BrowLeft=.23+.20*pulse;w.BrowRight=.12+.10*pulse;
    // Gaze anticipates the explanatory beat and returns before the turn ends.
    w.GazeRight=clamp(Math.sin(Math.PI*clamp((p-.06)/.74))*.52*profile.gaze);w.GazeLeft=0;
    w.SmileEyes=.44;
  }
  if(intent==='support'){w.SmileEyes=.50;w.Curious=.10;w.Attentive=.46;w.BrowLeft=.19;w.BrowRight=.14;}
  if(intent==='recall'){w.Curious=.23;w.Attentive=.48;w.BrowLeft=.23+micro;w.BrowRight=.12;}
  if(intent==='confirm'){w.SmileEyes=.79;w.BrowLeft=.25+.1*pulse;w.BrowRight=.19;}
  if(intent==='acknowledge'){w.SmileEyes=.55;w.SmileLeft*=.8;w.SmileRight*=.8;}
  w.BrowLeft=clamp(w.BrowLeft+micro);w.BrowRight=clamp(w.BrowRight-micro*.5);
  w.SmileLeft=clamp(w.SmileLeft*profile.smile);w.SmileRight=clamp(w.SmileRight*profile.smile);
  for(const name of faceNames)w[name]=clamp(w[name]);
}

export class TeachingFaceSmoother{
  constructor(){this.values=Object.fromEntries(faceNames.map(n=>[n,0]));this.initialized=false;}
  update(w,dt,enabled){
    const amount=!enabled||!this.initialized?1:1-Math.exp(-Math.max(0,dt)*12);
    for(const n of faceNames){this.values[n]+=(w[n]-this.values[n])*amount;w[n]=this.values[n];}
    this.initialized=true;
    // Smoothed smiles must not outlive a new closed/rounded mouth. Visemes
    // themselves and blinks are never smoothed or overwritten by this layer.
    const articulation=clamp((w.AA||0)+(w.EE||0)+(w.OO||0)+(w.UU||0)+(w.MBP||0)+.5*(w.FF||0)+.5*(w.TH||0));
    w.SmileLeft=Math.min(w.SmileLeft,1-.78*articulation);
    w.SmileRight=Math.min(w.SmileRight,1-.78*articulation);
  }
}

const audioStage=(id,phase,clip,text,extra={})=>({id,phase,clip,text,rate:1,...extra});
const waitStage=(id,phase,text,options)=>({id,phase,clip:null,text,options,hideAnswer:phase==='choice'||phase==='recall'});
export class CourseDirector{
  constructor({style='adult',rate=1,variation=0}={}){
    this.style=learnerStyles[style]?style:'adult';this.variation=variation%3;
    const child=this.style.startsWith('child');
    this.stages=[
      audioStage('welcome','introduce',child?'course_child_intro':'course_intro',child?'一起认识一个水果。':'先认识声音，再练习读音和回忆。'),
      audioStage('meaning','meaning','meaning_apple','苹果'),
      audioStage('whole','demonstrate','apple','先听完整的单词。',{rate}),
      audioStage('explain','explain',child?'course_child_sound':'course_sound',child?'听这个声音，再一起试一试。':'嘴张开，听 /æ/，再把声音放回单词。',{symbol:'æ'}),
      audioStage('sound','phoneme','phoneme_ae','/æ/',{symbol:'æ',rate}),
      audioStage('blend','demonstrate','apple','再听完整读音。',{rate}),
      audioStage('ask','invite','course_choice','听到的单词是什么意思？'),
      waitStage('choice','choice','刚才听到的是什么？',[{id:'apple',label:'苹果'},{id:'banana',label:'香蕉'},{id:'help',label:'再听一次'}]),
      audioStage('recall_prompt','invite',child?'course_child_recall':'course_recall',child?'看图片，试着说出它的英文。':'看含义，试着想起并说出英文。'),
      waitStage('recall','recall','苹果',[{id:'attempt',label:'我试过了'},{id:'help',label:'想不起来'}]),
      audioStage('transfer','transfer','course_transfer','回到完整单词，听过后再读一遍。'),
      audioStage('final_word','demonstrate','apple','apple',{rate}),
      waitStage('listen','listen','轮到你了。',[{id:'attempt',label:'我读好了'},{id:'help',label:'再听一次'}]),
      audioStage('close','finish','course_finish','今天的尝试完成了，下次再检查是否记得。'),
      {id:'finished',phase:'finished',clip:null},
    ];
    this.index=0;this.branch=[];this.evidence=[];
  }
  get stage(){return this.branch[0]||this.stages[this.index];}
  advance(){
    if(this.stage.phase==='finished'||this.stage.options)return this.stage;
    if(this.branch.length)this.branch.shift();else this.index++;
    return this.stage;
  }
  respond({action}={}){
    const current=this.stage;
    if(!current.options?.some(o=>o.id===action))return null;
    if(action==='help'||(current.phase==='choice'&&action==='banana')){
      if(action==='banana')this.evidence.push({goal:'word.apple.meaning',kind:'choice',correct:false,prompted:false});
      this.branch=[audioStage('support','support','course_support','一起再听一次。'),audioStage('help_word','demonstrate','apple','apple')];
      // The same question remains pending, with its answer still concealed.
      this.helped=true;return this.stage;
    }
    this.evidence.push(current.phase==='choice'?{goal:'word.apple.meaning',kind:'choice',correct:true,prompted:!!this.helped}:{goal:'word.apple.production',kind:'attempt',assessed:false});
    this.index++;this.helped=false;
    this.branch=[current.phase==='choice'?audioStage('confirmed','success','course_correct','选对了，这是苹果。'):audioStage('attempted','encourage','course_attempt','谢谢你的尝试。')];
    return this.stage;
  }
}
