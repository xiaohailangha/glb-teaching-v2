import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import * as THREE from 'three';
import {LessonDirector,PronunciationDirector,lessonPose,applyLessonFace,PoseSmoother} from '../assets/avatar/lesson-director.js';
import {NaturalMotion,makeTimeline} from '../assets/avatar/motion.js';

test('individual pronunciation plays only the selected unit and has an audio-driven mouth timeline',()=>{
  const folder=new URL('../assets/avatar/audio/',import.meta.url);
  const units=JSON.parse(fs.readFileSync(new URL('pronunciation-units.json',folder)));
  assert.equal(Object.keys(units).length,34);
  for(const [clip,unit] of Object.entries(units)){
    const d=new PronunciationDirector({word:'apple',clip,kind:unit.kind});
    assert.equal(d.stage.clip,clip);assert.equal(d.advance().phase,'finished');assert.equal(d.respond(),null);
    assert.ok(fs.statSync(new URL(clip+'.wav',folder)).size>1000);
    assert.ok(unit.cues.some(c=>c.id!==0));
    assert.ok(makeTimeline(unit.cues,clip).length>0);
    if(unit.kind==='phoneme')assert.equal(unit.phones.filter(p=>p!==7).length,1,'no letter name or added vowel: '+unit.symbol);
    else if(unit.kind==='group'){
      assert.equal(unit.symbol,'əl');
      assert.deepEqual(unit.phones.filter(p=>p!==7),[15,31]);
      const spoken=unit.cues.filter(c=>c.id!==0);
      assert.deepEqual(spoken.map(c=>c.id),[1,14]);
      assert.equal(unit.cues.filter(c=>c.time>spoken[0].time&&c.time<spoken.at(-1).time&&c.id===0).length,0);
    }else assert.equal(unit.voice,'Microsoft Huihui Desktop');
  }
});

test('normal teaching waits for learner input and never awards an automatic pronunciation result',()=>{
  const d=new LessonDirector({word:'apple'});
  assert.equal(d.stage.phase,'introduce');assert.equal(d.respond(),null);
  assert.equal(d.advance().clip,'apple');assert.equal(d.advance().phase,'invite');assert.equal(d.advance().phase,'listen');
  for(let i=0;i<100;i++)assert.equal(d.advance().phase,'listen');
  assert.equal(d.respond().phase,'encourage');assert.equal(d.respond(),null);
  assert.equal(d.advance().phase,'finished');
});

test('slow speech and repetitions affect the word, while retry and next-word intents choose matching prompts',()=>{
  const slow=new LessonDirector({word:'banana',rate:.75,repeat:3});
  assert.equal(slow.stage.clip,'intro_slow');assert.equal(slow.stage.rate,1);
  for(let i=0;i<3;i++){assert.equal(slow.advance().clip,'banana');assert.equal(slow.stage.rate,.75);assert.equal(slow.stage.iteration,i+1);}
  assert.equal(slow.advance().phase,'invite');assert.equal(slow.stage.rate,1);
  assert.equal(new LessonDirector({word:'cat',reason:'retry'}).stage.clip,'intro_retry');
  assert.equal(new LessonDirector({word:'cat',reason:'next'}).stage.clip,'intro_next');
});

test('all lessons and spoken prompts retain articulation with bounded face/body motion',()=>{
  const folder=new URL('../assets/avatar/audio/',import.meta.url);
  const assets={...JSON.parse(fs.readFileSync(new URL('timings.json',folder))),...JSON.parse(fs.readFileSync(new URL('teaching-prompts.json',folder)))};
  for(const [word,audio]of Object.entries(assets)){
    assert.ok(fs.existsSync(new URL(word+'.wav',folder)));
    const timeline=makeTimeline(audio.cues,word),motion=new NaturalMotion(()=>.5);
    const end=audio.cues.at(-1).time+.3;
    for(let i=0;i<=end*60;i++){
      const t=i/60;motion.update(1/60,{timeline,time:t,speaking:true,session:1});
      const originalAA=motion.weights.AA;applyLessonFace(motion.weights,'demonstrate',t/end,t,1);
      assert.equal(motion.weights.AA,originalAA);
      for(const n of ['SmileLeft','SmileEyes','BrowLeft','BrowRight','GazeRight','GazeLeft'])assert.ok(Number.isFinite(motion.weights[n])&&motion.weights[n]>=0&&motion.weights[n]<=1,word+' '+n);
    }
  }
  for(const phase of ['introduce','demonstrate','invite','listen','encourage'])for(let i=0;i<300;i++){
    const pose=lessonPose(phase,i/299,i/30,2);
    assert.ok(pose.time>=0&&pose.time<10);assert.ok(pose.accentTime>=0&&pose.accentTime<72);assert.ok(pose.accent>=0&&pose.accent<=1);
  }
});

test('body smoothing absorbs a clip change and converges at different frame rates',()=>{
  function simulate(fps){
    const bone=new THREE.Bone(),smoother=new PoseSmoother([bone]),target=new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(0,1,0),1);
    let first;
    for(let i=0;i<fps;i++){bone.quaternion.copy(target);smoother.update(1/fps,true);if(!i)first=bone.quaternion.angleTo(new THREE.Quaternion());}
    assert.ok(first<.5);return bone.quaternion;
  }
  assert.ok(simulate(30).angleTo(simulate(60))<1e-5);
});
