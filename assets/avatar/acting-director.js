import * as THREE from 'three';
import {curve} from './teaching-performance.js';

const clamp=x=>Math.max(0,Math.min(1,x));
// One continuous thought: greet, notice the word, explain, listen, reassure.
// Eyes anticipate the head; shoulders arrive later and retain their own pose.
const turn=[[0,.30],[1.6,.30],[2.7,.72],[4.8,.72],[6.0,.12],[8.0,.12],[9.5,-.48],[11.3,-.48],[13.0,.38],[15.4,.38],[17.3,.30],[18,.30]];
const interest=[[0,.20],[1.4,.62],[3.0,.35],[4.5,.72],[6.7,.16],[8.2,.45],[10.0,.82],[11.7,.60],[13.7,.18],[15.2,.75],[17.4,.35],[18,.20]];
const smile=[[0,.27],[1.3,.64],[2.8,.40],[4.8,.56],[6.4,.23],[8.2,.35],[10.5,.18],[12.0,.32],[14.2,.72],[15.5,.82],[17.4,.30],[18,.27]];
const lean=[[0,-.018],[2.2,-.018],[4.2,.028],[6.5,-.025],[9.0,-.025],[11.2,.04],[13.6,.005],[16,-.02],[18,-.018]];
const nod=[[0,.012],[1,.012],[1.6,-.025],[2.1,.018],[5,.018],[6,.055],[6.7,-.02],[7.3,.01],[10,.01],[11.8,-.028],[13,.02],[14.5,.045],[15.1,-.012],[16,.012],[18,.012]];
const faceNames=['SmileLeft','SmileRight','SmileEyes','BrowLeft','BrowRight','Curious','Attentive'];
export function actingSample(time){
  const t=((time%18)+18)%18;
  return {gaze:curve(turn,t+.18),head:curve(turn,t),body:curve(turn,Math.max(0,t-.32)),interest:curve(interest,t),smile:curve(smile,t),lean:curve(lean,t),nod:curve(nod,t)};
}

export class ActingDirector {
  constructor(model,rig){
    this.model=model;this.time=0;this.storyTime=null;this.applied=false;
    this.yaw=.30;this.headYaw=0;this.roll=0;this.pitch=0;this.gaze=0;
    this.face={};this.affect={};this.q=new THREE.Quaternion();this.euler=new THREE.Euler();this.pivot=new THREE.Vector3();
    this.head=model.getObjectByName(THREE.PropertyBinding.sanitizeNodeName(rig.head));
    this.arms=[];
    for(const side of ['L','R']){
      const elbow=model.getObjectByName(THREE.PropertyBinding.sanitizeNodeName('DEF-Forearm_1.'+side));
      if(!elbow)continue;const records=[];
      model.traverse(b=>{if(b.isBone&&b.name.endsWith(side)&&/^DEF-(Forearm_|Wrist|Finger)/.test(b.name))records.push({b,p:b.position.clone(),q:b.quaternion.clone()});});
      this.arms.push({side,elbow,records,amount:0});
    }
    this.parts=[];const names=new Set([rig.head,...rig.eyes,...rig.hair.map(h=>h.name)].map(THREE.PropertyBinding.sanitizeNodeName));
    model.traverse(b=>{if(b.isBone&&names.has(b.name))this.parts.push({b,p:b.position.clone(),q:b.quaternion.clone()});});
  }
  restore(){
    if(this.applied)for(const r of this.parts){r.b.position.copy(r.p);r.b.quaternion.copy(r.q);}
    if(this.applied)for(const arm of this.arms)for(const r of arm.records){r.b.position.copy(r.p);r.b.quaternion.copy(r.q);}
    this.applied=false;
  }
  update(dt,w,{speaking=false,engaged=false,storyTime=null,emoting=false,phase='idle'}={}){
    this.time+=dt;
    const sample=actingSample(storyTime??this.time);
    const gain=engaged||storyTime!==null?1:.60;
    // Listening returns attention to the learner without freezing breathing/posture.
    const listening=['listen','choice','recall'].includes(phase);
    // A celebratory turn belongs to the authored demo, never every word.
    const spin=storyTime===null?0:curve([[0,0],[14,0],[14.6,-.18],[15.2,0],[18.8,Math.PI*2],[24,Math.PI*2]],storyTime);
    let bodyTarget=sample.body*gain;
    if(listening)bodyTarget*=.35;
    if(['meaning','explain','transfer'].includes(phase))bodyTarget=.40+sample.body*.22;
    bodyTarget+=spin;
    const yawError=Math.atan2(Math.sin(bodyTarget-this.yaw),Math.cos(bodyTarget-this.yaw));
    this.yaw+=yawError*(1-Math.exp(-dt*4));
    const headTarget=(listening?-.18:(sample.head-.30)*.35-.12)*gain;
    this.headYaw+=(headTarget-this.headYaw)*(1-Math.exp(-dt*7));
    this.roll+=(sample.lean*gain-this.roll)*(1-Math.exp(-dt*5));
    this.pitch+=(sample.nod*gain-this.pitch)*(1-Math.exp(-dt*6));
    this.model.rotation.set(0,this.yaw,this.roll*.32);
    this.model.position.x=.018*Math.sin(this.time*.43)*gain+.025*Math.sin(spin);
    this.model.position.y=.0025*Math.sin(this.time*1.7)-.012*Math.pow(Math.sin(spin*.5),2);
    if(this.head){
      this.pivot.copy(this.head.position);this.pivot.y-=.035;
      this.q.setFromEuler(this.euler.set(this.pitch,this.headYaw,this.roll));
      // The exported rig is flattened. Rotate head, eyes and all hair together
      // around the same pivot so the scalp and eyeballs cannot detach.
      for(const r of this.parts){r.p.copy(r.b.position);r.q.copy(r.b.quaternion);r.b.position.sub(this.pivot).applyQuaternion(this.q).add(this.pivot);r.b.quaternion.premultiply(this.q);}
      this.applied=true;
    }
    // Carry the forearm and hand as one chain, with left/right timing offset.
    const gestureTime=storyTime??this.time%18;
    for(const arm of this.arms){
      const shift=arm.side==='L'?.30:0;
      const targetGesture=curve([[0,0],[2.0+shift,0],[3.7+shift,.52],[5.1+shift,.70],[6.7+shift,0],[12,0],[14,.46],[16,.64],[19,.15],[21,0],[24,0]],gestureTime)*(engaged&&!listening&&!emoting?1:0);
      arm.amount+=(targetGesture-arm.amount)*(1-Math.exp(-dt*7));const gesture=arm.amount;
      this.pivot.copy(arm.elbow.position);this.q.setFromEuler(this.euler.set(-gesture,0,gesture*(arm.side==='L'?-.12:.12)));
      for(const r of arm.records){r.p.copy(r.b.position);r.q.copy(r.b.quaternion);r.b.position.sub(this.pivot).applyQuaternion(this.q).add(this.pivot);r.b.quaternion.premultiply(this.q);}
    }
    if(!emoting){
      const articulation=clamp((w.AA||0)+(w.EE||0)+(w.OO||0)+(w.UU||0)+(w.MBP||0)+.5*(w.FF||0)+.5*(w.TH||0));
      const s=sample.smile,interest=sample.interest;
      const desired={SmileLeft:s*(1-.78*articulation),SmileRight:(s*.82+.025)*(1-.78*articulation),SmileEyes:.22+s*.78,BrowLeft:.08+interest*.47,BrowRight:.04+interest*.28,Curious:.05+interest*.25,Attentive:listening?.36:.10+interest*.18};
      for(const n of faceNames){
        const target=engaged?(w[n]||0)*.38+desired[n]*.62:desired[n];
        this.face[n]??=target;
        this.face[n]+=(target-this.face[n])*(1-Math.exp(-dt*(n.startsWith('Brow')?7:4.5)));
        w[n]=this.face[n];
      }
      w.SmileLeft=Math.min(w.SmileLeft,1-.78*articulation);w.SmileRight=Math.min(w.SmileRight,1-.78*articulation);
      // A short saccade has a held destination, not a sinusoidal wandering pupil.
      const eyeTarget=listening?0:(sample.gaze-.30)*gain*.9;
      this.gaze+=(eyeTarget-this.gaze)*(1-Math.exp(-dt*24));
      w.GazeRight=Math.max(0,this.gaze);w.GazeLeft=Math.max(0,-this.gaze);
      w.GazeDown=.025+.025*interest;w.GazeUp=0;
      // Low-strength overlapping thought accents, with separate attack/release.
      // They enrich silent listening; speech retains its own articulation.
      const tA=(storyTime??this.time)%18;
      const pulse=(a,b,c,d)=>curve([[0,0],[a,0],[b,1],[c,.72],[d,0],[18,0]],tA);
      const accents={curious:pulse(2.1,3.5,4.5,6.0)*.30,confused:pulse(5.7,7.0,8.0,9.5)*.27,relieved:pulse(11.0,12.7,13.4,15.0)*.22,happy:pulse(13.5,14.7,15.3,17.4)*.22};
      for(const [name,value]of Object.entries(accents)){
        const target=speaking?0:value*gain;
        this.affect[name]??=0;this.affect[name]+=(target-this.affect[name])*(1-Math.exp(-dt*(speaking?30:6)));
        w['Emotion_'+name]=this.affect[name]*(1-articulation);
        w['EmotionBlink_'+name]=(w.Blink||0)*w['Emotion_'+name];
      }
      // Blink during the change of attention.
      const t=(storyTime??this.time)%18;
      for(const start of [2.0,5.6,9.0,12.5,16.6]){
        const d=t-start;if(d>=0&&d<.23)w.Blink=Math.max(w.Blink||0,curve([[0,0],[.065,1],[.095,1],[.23,0]],d));
      }
    }
  }
}
