export const mouthNames=['AA','EE','OO','UU','FF','MBP','TH','L'];
export const visemeLabels=['','æ / ə / ʌ','ɑ','ɔ','e / ɛ / ʊ','ɜ','i / ɪ','u / w','oʊ','aʊ','ɔɪ','aɪ','h','r','l','s / z','ʃ / tʃ','θ / ð','f / v','t / d / n','k / ɡ / ŋ','p / b / m'];
const poses=[{}, {AA:.72},{AA:.82},{OO:.60,AA:.12},{AA:.34,EE:.16},{UU:.32},{EE:.59},
  {UU:.80},{OO:.76},{AA:.55},{OO:.55},{AA:.48,EE:.12},{AA:.18},{UU:.32},
  {L:.62},{EE:.24},{OO:.28,EE:.16},{TH:.76},{FF:.78},{L:.40},{AA:.24},{MBP:.96}];
const clamp=x=>Math.max(0,Math.min(1,x));
const smooth=x=>{x=clamp(x);return x*x*(3-2*x);};
const damp=(a,b,lambda,dt)=>a+(b-a)*(1-Math.exp(-lambda*dt));

export function makeTimeline(cues,word=''){
  let first=true;
  return cues.map(cue=>{
    let id=cue.id;
    // Zira emits an alveolar viseme for the initial /θ/ in this fixed lesson.
    // This is an explicit visual correction, not an automatic phonetic score.
    if(id!==0&&first){if((word==='thank'||word==='phoneme_th')&&id===19)id=17;first=false;}
    const values=new Float32Array(mouthNames.length);
    for(const [name,value]of Object.entries(poses[id]||{}))values[mouthNames.indexOf(name)]=value;
    return {time:cue.time,id,values};
  });
}

export function sampleTimeline(timeline,time,rate=1,out=new Float32Array(8)){
  out.fill(0);
  if(!timeline?.length)return 0;
  let index=0;
  while(index+1<timeline.length&&timeline[index+1].time<=time)index++;
  // Adjacent windows never overlap, including short /p/ and /t/ intervals.
  // Source-time windows scale with speed to preserve physical transition time.
  const next=timeline[index+1];
  let a=timeline[index],b=a,blend=0;
  const previousRadius=index>0?boundaryRadius(timeline,index,rate):0;
  const nextRadius=next?boundaryRadius(timeline,index+1,rate):0;
  if(index>0&&time<timeline[index].time+previousRadius){
    a=timeline[index-1];b=timeline[index];
    blend=smooth((time-b.time+previousRadius)/Math.max(.001,previousRadius*2));
  }else if(next&&time>=next.time-nextRadius){
    b=next;blend=smooth((time-next.time+nextRadius)/Math.max(.001,nextRadius*2));
  }
  let total=0;
  for(let i=0;i<8;i++){out[i]=a.values[i]+(b.values[i]-a.values[i])*blend;total+=out[i];}
  // Strong labial closure must suppress competing open-vowel poses.
  const closure=out[5];
  if(closure>0){for(let i=0;i<8;i++)if(i!==5)out[i]*=(1-closure)*(1-closure);}
  if(total>1){for(let i=0;i<8;i++)out[i]/=total;}
  return timeline[index].id;
}

function boundaryRadius(timeline,index,rate){
  return Math.min(.0325*rate,(timeline[index].time-timeline[index-1].time)*.35,
    timeline[index+1]?(timeline[index+1].time-timeline[index].time)*.35:Infinity);
}

export class NaturalMotion {
  constructor(random=Math.random){
    this.random=random;this.time=0;this.nextBlink=1.8+random()*2;this.blinkAt=-10;
    this.nextPosture=0;this.look=0;this.lookTarget=0;this.nod=0;this.nodTarget=.07;
    this.talk=0;this.gesture=0;this.lastSession=null;this.phase=random()*6.28;
    this.mouth=new Float32Array(8);this.target=new Float32Array(8);this.weights={};
  }
  update(dt,{timeline=null,time=0,rate=1,speaking=false,session=null,progress=0,level=0}={}){
    dt=Math.max(0,Math.min(.05,dt));this.time+=dt;const t=this.time,w=this.weights;
    let id=0;
    if(speaking)id=sampleTimeline(timeline,time,rate,this.target);else this.target.fill(0);
    for(let i=0;i<8;i++){
      // Closure has a short attack; opening and release stay softer. Tiny
      // residuals become exact zero, avoiding needless GPU morph texture reads.
      const speed=i===5&&this.target[i]>this.mouth[i]?58:42;
      this.mouth[i]=damp(this.mouth[i],this.target[i],speed,dt);
      if(this.mouth[i]<.0005)this.mouth[i]=0;
      w[mouthNames[i]]=this.mouth[i];
    }
    if(t>=this.nextBlink){
      this.blinkAt=t;this.nextBlink=t+(this.random()<.08?.32:2.8+this.random()*3.7);
    }
    const blinkTime=t-this.blinkAt;
    let blink=0;
    if(blinkTime<.07)blink=smooth(blinkTime/.07);
    else if(blinkTime<.095)blink=1;
    else if(blinkTime<.24)blink=1-smooth((blinkTime-.095)/.145);
    w.Blink=.10+.90*blink;
    if(t>=this.nextPosture){
      this.nextPosture=t+3.5+this.random()*3;
      this.lookTarget=(this.random()-.5)*.17;
      this.nodTarget=.02+this.random()*.12;
    }
    this.look=damp(this.look,this.lookTarget,2.4,dt);
    this.nod=damp(this.nod,this.nodTarget,1.8,dt);
    this.talk=damp(this.talk,speaking?1:0,5,dt);
    if(session!==this.lastSession){this.lastSession=session;this.gestureAmount=.045+this.random()*.045;}
    const vowel=[1,2,3,4,6,7,8,9,10,11].includes(id);
    const emphasis=vowel?Math.min(.12,level*.12):0;
    this.gesture=damp(this.gesture,speaking?Math.sin(Math.PI*clamp(progress))*(this.gestureAmount||.06):0,4,dt);
    w.HeadNod=this.nod+this.talk*emphasis;
    w.LookRight=Math.max(0,this.look);w.LookLeft=Math.max(0,-this.look);
    w.Breathe=.22+.12*Math.sin(t*1.15+this.phase)+.025*Math.sin(t*.47+this.phase);
    w.Gesture=this.gesture;
    w.BrowRelax=.30;w.BrowUp=.02+this.talk*emphasis*.4;
    w.Smile=.045*(1-this.talk);
    return id;
  }
}
