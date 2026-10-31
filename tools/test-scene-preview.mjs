import fs from 'node:fs/promises';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
const origin='https://49.233.179.83';
const checks=[];
async function check(name,task){await task();checks.push(name);console.log('PASS '+name);}
const get=path=>fetch(new URL(path,origin),{signal:AbortSignal.timeout(30000)});
await check('new scene entry is directly accessible',async()=>{
 const r=await get('/scene/');assert.equal(r.status,200);assert.match(await r.text(),/<base href="\/scene\/">/);assert.equal(r.headers.get('www-authenticate'),null);
});
await check('original web entry is unchanged',async()=>{
 const r=await get('/');assert.equal(r.status,200);assert.equal(await r.text(),await fs.readFile('build/web/index.html','utf8'));
});
await check('both cloud model versions remain independent',async()=>{
 const original=await(await get('/api/assets/model-manifest')).json(),scene=await(await get('/api/assets/scene-manifest')).json();
 assert.equal(original.parts.length,147);assert.equal(original.revision,'a727ba3e745250b1502a6aed4ba135f6b5d534c0f8da2b81cb7ca87757354af3');
 assert.equal(scene.parts.length,89);assert.equal(scene.revision,'b8af9ea92ea8c156272010987f5fdae1c5fa8c2d9dd9a1cf769c325443ae93a0');
 for(const part of [scene.parts[0],scene.parts.at(-1)]){
  const r=await fetch(part.url,{signal:AbortSignal.timeout(30000)});assert.equal(r.status,200);const bytes=Buffer.from(await r.arrayBuffer());assert.equal(bytes.length,part.size);assert.equal(crypto.createHash('sha256').update(bytes).digest('hex'),part.sha256);
 }
});
await check('new renderer assets and curated phonemes are available',async()=>{
 for(const path of ['/scene/main.dart.js','/scene/assets/assets/avatar/audio/silence.wav','/scene/assets/assets/avatar/audio/pronunciation-units.json','/scene/assets/assets/avatar/models/storm-clothing-bindings.bin','/scene/assets/assets/avatar/models/storm-clothing-bindings.json']){
  const r=await get(path);assert.equal(r.status,200);assert.ok(Number(r.headers.get('content-length'))>0);const bytes=Buffer.from(await r.arrayBuffer());
  assert.equal(crypto.createHash('sha256').update(bytes).digest('hex'),crypto.createHash('sha256').update(await fs.readFile('scene-preview/build/web'+path.slice('/scene'.length))).digest('hex'));
 }
});
await check('Tencent synthesis and matching mouth data remain usable',async()=>{
 assert.equal((await(await get('/api/speech/status')).json()).configured,true);
 const r=await fetch(origin+'/api/speech/tts',{method:'POST',headers:{'Content-Type':'application/json',Origin:origin},body:JSON.stringify({text:'apple',language:'en',voice:403008,speed:0}),signal:AbortSignal.timeout(100000)});
 assert.equal(r.status,200);const speech=await r.json();assert.equal(speech.usable,true);assert.ok(speech.cues.length>0);assert.match(speech.audioUrl,/^\/api\/speech\/audio\/[a-f0-9]{64}\.wav$/);const audio=await get(speech.audioUrl);assert.equal(audio.status,200);await audio.arrayBuffer();
});
await check('all shipped teaching voices and word bytes match the boy-voice build',async()=>{
 for(const file of ['timings','teaching-prompts','course-prompts','pronunciation-units','fruit-prompts','coach-prompts']) {
  const response=await get(`/scene/assets/assets/avatar/audio/${file}.json`);
  assert.equal(response.status,200);const items=await response.json();
  for(const [key,item] of Object.entries(items)) {
   if(item.kind==='phoneme')assert.equal(item.reference,true,key);else assert.equal(item.voice,403008,key);assert.equal(item.bundled,true,key);
   if(file==='timings'||file==='fruit-prompts'||item.kind==='phoneme') {
    const response=await get(`/scene/assets/assets/avatar/audio/${key}.wav`);
    assert.equal(response.status,200);
    const bytes=Buffer.from(await response.arrayBuffer());
    const local=await fs.readFile(`scene-preview/assets/avatar/audio/${key}.wav`);
    assert.equal(crypto.createHash('sha256').update(bytes).digest('hex'),crypto.createHash('sha256').update(local).digest('hex'));
   }
  }
 }
 assert.equal((await get('/scene/voice-review.html')).status,200);
});
await check('adult fruit course publishes the complete versioned lesson',async()=>{
 const response=await get('/scene/assets/assets/avatar/courses/adult-fruit.json');
 assert.equal(response.status,200);
 const course=await response.json();
 assert.deepEqual(course,JSON.parse(await fs.readFile('scene-preview/assets/avatar/courses/adult-fruit.json','utf8')));
 assert.equal(course.id,'adult-fruit-v2');
 assert.equal(course.stages.at(-1).id,'summary');
 assert.equal(course.stages.some(s=>s.id.startsWith('review_')),false);
 assert.equal(course.stages.at(-2).id,'red_sentence');
 assert.equal(course.stages.filter(s=>s.answer).length,3);
});
await check('private files and cross-site spending remain blocked',async()=>{
 for(const path of ['/scene/.secrets/tencent.json','/scene/services/cos-assets.mjs','/.secrets/tencent.json']){const response=await get(path);assert.ok([403,404].includes(response.status));await response.arrayBuffer();}
 const denied=await fetch(origin+'/api/speech/tts',{method:'POST',headers:{Origin:'https://example.org','Content-Type':'application/json'},body:'{}'});assert.equal(denied.status,403);await denied.arrayBuffer();
});
await fs.mkdir('docs/flutter-scene',{recursive:true});
await fs.writeFile('docs/flutter-scene/web-verification.json',JSON.stringify({origin:origin+'/scene/',checkedAt:new Date().toISOString(),passed:checks.length,checks,phonePerformanceVerified:false,recordingVerified:false},null,2)+'\n');
