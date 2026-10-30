import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {CourseDirector,coursePose,applyCourseFace,TeachingFaceSmoother,learnerStyles,teachingIntent,actingRules} from '../assets/avatar/course-director.js';

const read=name=>JSON.parse(fs.readFileSync(new URL('../assets/avatar/audio/'+name,import.meta.url)));
const clips={...read('timings.json'),...read('pronunciation-units.json'),...read('course-prompts.json')};
function advanceToWait(d){let limit=40;while(!d.stage.options&&d.stage.phase!=='finished'&&limit--)d.advance();assert.ok(limit>0);}

test('authored course uses existing audio and waits for explicit responses',()=>{
  for(const style of Object.keys(learnerStyles)){
    const d=new CourseDirector({style});
    for(const s of d.stages){
      if(s.clip){assert.ok(clips[s.clip],s.clip);assert.ok(fs.existsSync(new URL('../assets/avatar/audio/'+s.clip+'.wav',import.meta.url)));}
      if(s.phase!=='finished')assert.ok(actingRules[teachingIntent[s.phase]],s.phase);
    }
    advanceToWait(d);assert.equal(d.stage.phase,'choice');assert.equal(d.stage.hideAnswer,true);
    for(let i=0;i<50;i++)assert.equal(d.advance().phase,'choice');
    assert.equal(d.respond({action:'invented'}),null);
    assert.equal(d.respond({action:'banana'}).phase,'support');
    assert.equal(d.respond({action:'apple'}),null,'cannot skip spoken support');
    advanceToWait(d);assert.equal(d.stage.phase,'choice');
    assert.equal(d.respond({action:'apple'}).phase,'success');
    assert.equal(d.evidence.at(-1).prompted,true);
    advanceToWait(d);assert.equal(d.stage.phase,'recall');
    d.respond({action:'help'});advanceToWait(d);assert.equal(d.stage.phase,'recall');
    d.respond({action:'attempt'});advanceToWait(d);assert.equal(d.stage.phase,'listen');
    d.respond({action:'attempt'});advanceToWait(d);assert.equal(d.stage.phase,'finished');
    assert.equal(d.respond({action:'attempt'}),null);
    assert.ok(d.evidence.filter(e=>e.kind==='attempt').every(e=>e.assessed===false&&!('correct' in e)));
  }
});

test('course speech has actual local audio and nonempty viseme timing',()=>{
  for(const [id,item]of Object.entries(read('course-prompts.json'))){
    assert.ok(item.cues.length>2,id);assert.ok(item.cues.some(c=>c.id!==0),id);
    assert.ok(item.cues.every((c,i)=>!i||c.time>=item.cues[i-1].time),id);
    assert.ok(fs.statSync(new URL('../assets/avatar/audio/'+id+'.wav',import.meta.url)).size>1000);
  }
});

test('all course intentions retain articulation, bounded poses and patient waiting',()=>{
  for(const style of Object.keys(learnerStyles))for(const phase of Object.keys(teachingIntent))for(let i=0;i<=120;i++){
    const w={AA:.25,EE:.1,MBP:.4,OO:0,UU:0,FF:0,TH:.2,L:.3,Blink:.9};
    applyCourseFace(w,phase,i/120,i*2,1,style);
    const pose=coursePose(phase,i/120,i*2,1,style);
    assert.equal(w.AA,.25);assert.equal(w.MBP,.4);assert.equal(w.TH,.2);assert.equal(w.Blink,.9);
    for(const v of Object.values(w))assert.ok(Number.isFinite(v)&&v>=0&&v<=1,phase);
    assert.ok(pose.time>=0&&pose.time<10);assert.ok(pose.accentTime>=0&&pose.accentTime<72);assert.ok(pose.accent<=.48);
    assert.ok(!('Emotion_angry' in w)&&!('Emotion_frustrated' in w));
  }
});

test('expression changes are smoothed without delaying mouth closure or blink',()=>{
  function run(fps){
    const s=new TeachingFaceSmoother();const w={AA:0,MBP:0,Blink:1};applyCourseFace(w,'listen',0,0);s.update(w,1/fps,true);
    const before=w.SmileEyes;
    for(let i=0;i<fps;i++){applyCourseFace(w,'success',.5,1);s.update(w,1/fps,true);if(!i)assert.ok(w.SmileEyes<.79&&w.SmileEyes>before);}
    const end=w.SmileEyes;w.MBP=1;s.update(w,1/fps,true);assert.ok(w.SmileLeft<=.22+1e-8);assert.equal(w.MBP,1);assert.equal(w.Blink,1);return end;
  }
  assert.ok(Math.abs(run(30)-run(60))<1e-6);
});
