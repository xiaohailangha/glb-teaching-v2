import fs from 'node:fs';
import assert from 'node:assert/strict';
import {audioHash,sameSpeech} from '../services/course-audio-quality.mjs';
import {readWave} from '../services/tencent-speech.mjs';
const read=p=>JSON.parse(fs.readFileSync(p,'utf8')),root='scene-preview/assets/avatar';
const catalog=read('data/course-catalog.json'),review=read('data/curriculum/release-quality.json');
assert.equal(audioHash(fs.readFileSync('data/course-catalog.json')),review.catalogHash);
for(const file of review.files)assert.equal(audioHash(fs.readFileSync(file.path)),file.sha256,file.path);
assert.equal(catalog.types.length,8);
assert.equal(catalog.courses.length,96);
assert.equal(new Set(catalog.courses.map(c=>c.id)).size,96);
assert.ok(catalog.courses.every(c=>!c.id.startsWith('adult-')));
const grouped=catalog.types.flatMap(t=>{assert.equal(t.courseIds.length,12,t.id);return t.courseIds;});
assert.equal(new Set(grouped).size,96);
const audio=Object.assign({},...fs.readdirSync(root+'/audio').filter(n=>n.endsWith('.json')).map(n=>read(root+'/audio/'+n)));
const vocabulary=new Map(catalog.lexicon.map(w=>[w.word,w]));
let stages=0,targets=0;
for(const course of catalog.courses){
 const source=read(root+'/courses/'+course.asset+'.json');
 assert.equal(source.id,course.id);
 assert.equal(new Set(source.stages.map(s=>s.id)).size,source.stages.length);
 if(course.id==='food-01-v1'){
  assert.ok(!JSON.stringify(source.stages).includes('orange'));
  assert.ok(!source.stages.some(s=>s.phase==='choice'||s.answer));
  const modelled=new Set();
  for(const stage of source.stages){
   if(stage.phase==='demonstrate')modelled.add(stage.speechText);
   if(stage.phase==='listen')assert.ok(modelled.has(stage.speechText),'Unmodelled fruit practice: '+stage.id);
  }
 }else assert.ok(source.stages.some(s=>s.phase==='recall'));
 assert.equal(source.stages.at(-1).id,'summary');
 for(const stage of source.stages){
  stages++;
  if(stage.answer)assert.equal(stage.options.filter(o=>o.id===stage.answer).length,1);
  for(const key of [stage.clip,stage.practiceClip].filter(Boolean)){
   assert.ok(audio[key],key);assert.ok(fs.existsSync(root+'/audio/'+key+'.wav'),key);
   if(stage.speechText){assert.ok(sameSpeech(stage.speechText,audio[key].text),course.id+'/'+stage.id);targets++;}
  }
  if(stage.speechText)for(const [word] of stage.speechText.toLowerCase().matchAll(/[a-z]+(?:'[a-z]+)?/g))assert.ok(vocabulary.has(word),'Missing clickable word: '+word);
 }
}
for(const item of review.audio){
 const bytes=fs.readFileSync(root+'/audio/'+item.key+'.wav'),{duration,pcm}=readWave(bytes);
 assert.equal(audioHash(bytes),item.sha256,item.key);
 assert.ok(Math.abs(duration-audio[item.key].duration)<.001,item.key);
 const cues=audio[item.key].cues;
 assert.equal(cues.at(-1).id,0,item.key);
 assert.ok(cues.every((c,i)=>c.time>=0&&c.time<=duration&&(i===0||c.time>=cues[i-1].time)),item.key);
 if(audio[item.key].trim)assert.ok(pcm.subarray(-3200).every(b=>b===0),'Non-silent trimmed tail: '+item.key);
}
for(const word of vocabulary.values())assert.ok(audio[word.clip]?.quality,'Missing verified word: '+word.word);
const report={checkedAt:new Date().toISOString(),categories:8,courses:96,stages,spokenTargets:targets,verifiedAudio:review.audio.length,lexicon:vocabulary.size,files:review.files.length,passed:true};
fs.writeFileSync('work/curriculum/final-verification.json',JSON.stringify(report,null,2));
console.log(JSON.stringify(report));
