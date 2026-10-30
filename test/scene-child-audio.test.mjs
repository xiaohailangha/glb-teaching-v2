import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {readWave} from '../services/tencent-speech.mjs';

const root=new URL('../scene-preview/assets/avatar/audio/',import.meta.url);
const read=name=>JSON.parse(fs.readFileSync(new URL(name+'.json',root)));

test('every published course sound and segment resolves to a bundled asset',()=>{
 const course=JSON.parse(fs.readFileSync(new URL('../courses/adult-fruit.json',root)));
 const audio=Object.assign({},...['timings','fruit-prompts'].map(read));
 const ids=new Set();
 for(const stage of course.stages){
  assert.ok(!ids.has(stage.id),stage.id);ids.add(stage.id);
  for(const clip of [stage.clip,stage.practiceClip,...(stage.segments||[]).map(s=>s.clip)].filter(Boolean)){
   assert.ok(audio[clip],`${stage.id}: missing ${clip}`);
   assert.ok(fs.existsSync(new URL(clip+'.wav',root)),clip);
  }
  if(stage.speechText)assert.equal(audio[stage.practiceClip].text.replace(/[.!?]/g,''),stage.speechText.replace(/[.!?]/g,''),stage.id);
 }
 assert.equal(course.id,'adult-fruit-v2');
});
test('teaching words use boy voice and isolated IPA uses attributed standalone reference recordings',()=>{
  let count=0;
  for(const file of ['timings','teaching-prompts','course-prompts','pronunciation-units','fruit-prompts']) {
    for(const [key,item] of Object.entries(read(file))) {
      if(item.kind==='phoneme') { assert.equal(item.reference,true,key);assert.ok(item.source?.license,key);assert.equal(item.sourceWord,undefined,key); } else assert.equal(item.voice,403008,key);
      assert.equal(item.bundled,true,key);
      const {duration}=readWave(fs.readFileSync(new URL(key+'.wav',root)));
      assert.ok(Math.abs(duration-item.duration)<.001,key);
      let last=-1;
      for(const cue of item.cues) {
        assert.ok(cue.time>=last&&cue.time<=duration,key);
        last=cue.time;
      }
      assert.equal(item.cues.at(-1).id,0,key);
      if(file==='timings') {
        assert.equal(item.text,key);
        assert.ok(duration<2,`${key}: unexpected trailing audio`);
      }
      count++;
    }
  }
  assert.equal(count,94);
});
test('retired word cuts stay absent and performance retains its authored clock',()=>{
  assert.equal(read('pronunciation-units').group_schwa_l,undefined);
  assert.equal(read('pronunciation-units').phoneme_ow,undefined);
  const performance=read('performance-cues');
  assert.equal(performance.voice,403008);
  assert.equal(readWave(fs.readFileSync(new URL('performance.wav',root))).duration,10);
  assert.equal(performance.cues.at(-1).time,10);
});
