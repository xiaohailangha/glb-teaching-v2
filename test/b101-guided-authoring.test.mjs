import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import crypto from 'node:crypto';
import {sample,runtimeChecks} from '../services/curriculum.mjs';

test('six guided lessons teach meanings and model every speaking target before practice',()=>{
 const lessons=Object.entries(sample.guidedLessons);
 assert.equal(lessons.length,6);
 const audio=new Map(sample.audio.map(a=>[a.id,a]));
 for(const [course,steps] of lessons){
  assert.equal(steps[0].phase,'开场');
  assert.equal(steps.at(-1).phase,'收束');
  const modeled=new Set();
  for(let i=0;i<steps.length;i++){
   const step=steps[i];
   assert.equal(step.course,course);
   if(step.audio)assert(audio.has(step.audio),step.audio);
   if(step.phase==='示范'){
    assert.equal(steps[i-1].phase,'释义');
    assert.equal(audio.get(steps[i-1].audio).language,'zh');
    assert.equal(steps[i+1].phase,'跟读');
    assert.equal(steps[i+1].model,step.audio);
    modeled.add(step.audio);
   }
   if(step.check){
    const check=runtimeChecks.find(c=>c.id===step.check);
    assert(check,step.check);
    assert(!check.options,step.check);
    assert(modeled.has(step.model),`${course}: untaught practice ${step.model}`);
   }
  }
 }
});

test('new narrated assets have independent review and phoneme timing metadata',()=>{
 const release=JSON.parse(fs.readFileSync(new URL('../data/curriculum/teaching-audio.json',import.meta.url)));
 const authored=sample.audio.filter(a=>a.id.startsWith('B102-'));
 assert.equal(release.assets.length,authored.length);
 for(const item of authored){
  const a=release.assets.find(a=>a.id===item.id);
  assert.equal(a.text,item.text);
  assert.equal(a.secondPass.sha256,a.sha256);
  assert(a.duration>0&&a.cues.length>0,a.id);
  // Locally prepared recordings are optional on CI; verify bytes when present.
  const file=new URL(`../work/b101-guided-v2/${a.id}.wav`,import.meta.url);
  if(fs.existsSync(file)){
   const bytes=fs.readFileSync(file);
   assert.equal(bytes.length,a.size);
   assert.equal(crypto.createHash('sha256').update(bytes).digest('hex'),a.sha256);
  }
 }
});
