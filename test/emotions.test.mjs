import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {emotionIds,emotionEnvelope,applyEmotionFace} from '../assets/avatar/emotions.js';

test('every emotion returns to neutral and has continuous, finite expression and gaze weights',()=>{
  const catalog=JSON.parse(fs.readFileSync(new URL('../assets/data/emotions.json',import.meta.url)));
  assert.deepEqual(emotionIds,catalog.map(e=>e.id));
  for(const id of emotionIds){
    const weights={Blink:1,SmileLeft:1,AA:1};let previous={};
    assert.equal(emotionEnvelope(id,0),0);assert.equal(emotionEnvelope(id,6),0);
    for(let i=0;i<=1440;i++){
      applyEmotionFace(weights,id,i/240);
      for(const [key,value]of Object.entries(weights)){
        assert.ok(Number.isFinite(value)&&value>=0&&value<=1,id+' '+key);
        if(i)assert.ok(Math.abs(value-(previous[key]||0))<.12,id+' '+key);
      }
      assert.equal(weights.AA,0);assert.equal(weights.SmileLeft,0);
      previous={...weights};
    }
  }
});

test('asset has all twelve authored expressions, independent blink corrections and a 72-second skeletal reel',()=>{
  const bytes=fs.readFileSync(new URL('../assets/avatar/models/storm-performance.glb',import.meta.url));
  const doc=JSON.parse(bytes.toString('utf8',20,20+bytes.readUInt32LE(12)));
  const head=doc.meshes[doc.nodes.find(n=>n.name==='Storm_head').mesh];
  for(const id of emotionIds){
    assert.ok(head.extras.targetNames.includes('Emotion_'+id),id);
    // Storm's compressed disgust pose already closes the eyes completely.
    if(id!=='disgusted')assert.ok(head.extras.targetNames.includes('EmotionBlink_'+id),'blink '+id);
  }
  const clip=doc.animations.find(a=>a.name==='Emotion_Reel');assert.ok(clip);
  assert.equal(Math.max(...clip.samplers.map(s=>doc.accessors[s.input].max[0])),72);
  assert.ok(clip.channels.length>=72);
});
