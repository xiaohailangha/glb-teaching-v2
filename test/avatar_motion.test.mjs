import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {NaturalMotion,makeTimeline,sampleTimeline} from '../assets/avatar/motion.js';

test('articulation blends continuously at every boundary including short consonants',()=>{
  const timeline=makeTimeline([{time:0,id:0},{time:.15,id:1},{time:.28,id:21},{time:.32,id:6},{time:.52,id:0}]);
  const a=new Float32Array(8),b=new Float32Array(8);
  for(const rate of [.75,1])for(let t=.001;t<.7;t+=.001){
    sampleTimeline(timeline,t-.001,rate,a);sampleTimeline(timeline,t,rate,b);
    for(let i=0;i<8;i++)assert.ok(Math.abs(a[i]-b[i])<.11,`discontinuity ${rate} ${t} ${i}`);
  }
});
test('labial closure suppresses the previous open vowel; silence settles exactly',()=>{
  const timeline=makeTimeline([{time:0,id:1},{time:.2,id:21},{time:.4,id:0}]);
  const pose=sampleTimeline(timeline,.25);assert.equal(pose,21);
  const values=new Float32Array(8);sampleTimeline(timeline,.25,1,values);
  assert.ok(values[5]>.9);assert.ok(values[0]<.01);
  const motion=new NaturalMotion(()=>.5);
  for(let i=0;i<30;i++)motion.update(1/60,{timeline,time:.1,speaking:true});
  for(let i=0;i<80;i++)motion.update(1/60,{speaking:false});
  for(const name of ['AA','EE','OO','UU','FF','MBP','TH','L'])assert.equal(motion.weights[name],0);
});
test('all ten lessons remain bounded during normal/slow speech, cancellation, and idle',()=>{
  const data=JSON.parse(fs.readFileSync(new URL('../assets/avatar/audio/timings.json',import.meta.url)));
  for(const [word,item]of Object.entries(data))for(const rate of [.75,1]){
    const timeline=makeTimeline(item.cues,word),motion=new NaturalMotion(()=>.45);
    for(let i=0;i<240;i++){
      motion.update(1/60,{timeline,time:i/60*rate,speaking:i<140,rate,session:word,progress:Math.min(1,i/140),level:.6});
      for(const [key,value]of Object.entries(motion.weights))assert.ok(Number.isFinite(value)&&value>=0&&value<=1,`${word} ${key} ${value}`);
    }
  }
});
test('thank corrects the fixed initial theta cue without changing alveolars elsewhere',()=>{
  const cues=[{time:0,id:0},{time:.15,id:19},{time:.4,id:19}];
  assert.deepEqual(makeTimeline(cues,'thank').map(x=>x.id),[0,17,19]);
  assert.deepEqual(makeTimeline(cues,'dog').map(x=>x.id),[0,19,19]);
});
test('posture and blink do not depend on 30 versus 60 FPS integration',()=>{
  const a=new NaturalMotion(()=>.5),b=new NaturalMotion(()=>.5);
  for(let i=0;i<60;i++)a.update(1/60);
  for(let i=0;i<30;i++)b.update(1/30);
  for(const name of ['LookRight','LookLeft','HeadNod','Breathe','Blink'])assert.ok(Math.abs(a.weights[name]-b.weights[name])<.005,name);
});
