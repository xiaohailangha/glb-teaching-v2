import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {readWave} from '../services/tencent-speech.mjs';

const root=new URL('../scene-preview/assets/avatar/audio/',import.meta.url);
const read=name=>JSON.parse(fs.readFileSync(new URL(name+'.json',root)));
test('all scene teaching assets use one bundled boy voice with in-range matching cues',()=>{
  let count=0;
  for(const file of ['timings','teaching-prompts','course-prompts','pronunciation-units']) {
    for(const [key,item] of Object.entries(read(file))) {
      assert.equal(item.voice,403008,key);
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
  assert.equal(count,65);
});
test('apple ending is one continuous same-speaker cut and performance retains its authored clock',()=>{
  const group=read('pronunciation-units').group_schwa_l;
  assert.equal(group.sourceWord,'apple');
  assert.deepEqual(group.sourcePhones.map(p=>p.phone),['ah','l']);
  assert.equal(group.sourcePhones[0].end,group.sourcePhones[1].start);
  const performance=read('performance-cues');
  assert.equal(performance.voice,403008);
  assert.equal(readWave(fs.readFileSync(new URL('performance.wav',root))).duration,10);
  assert.equal(performance.cues.at(-1).time,10);
});
