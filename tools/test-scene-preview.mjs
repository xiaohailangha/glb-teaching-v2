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
 for(const path of ['/scene/main.dart.js','/scene/assets/assets/avatar/audio/silence.wav','/scene/assets/assets/avatar/audio/pronunciation-units.json']){
  const r=await get(path);assert.equal(r.status,200);assert.ok(Number(r.headers.get('content-length'))>0);await r.arrayBuffer();
 }
});
await check('Tencent synthesis and matching mouth data remain usable',async()=>{
 assert.equal((await(await get('/api/speech/status')).json()).configured,true);
 const r=await fetch(origin+'/api/speech/tts',{method:'POST',headers:{'Content-Type':'application/json',Origin:origin},body:JSON.stringify({text:'apple',language:'en',voice:403007,speed:0}),signal:AbortSignal.timeout(100000)});
 assert.equal(r.status,200);const speech=await r.json();assert.equal(speech.usable,true);assert.ok(speech.cues.length>0);assert.match(speech.audioUrl,/^\/api\/speech\/audio\/[a-f0-9]{64}\.wav$/);const audio=await get(speech.audioUrl);assert.equal(audio.status,200);await audio.arrayBuffer();
});
await check('private files and cross-site spending remain blocked',async()=>{
 for(const path of ['/scene/.secrets/tencent.json','/scene/services/cos-assets.mjs','/.secrets/tencent.json']){const response=await get(path);assert.ok([403,404].includes(response.status));await response.arrayBuffer();}
 const denied=await fetch(origin+'/api/speech/tts',{method:'POST',headers:{Origin:'https://example.org','Content-Type':'application/json'},body:'{}'});assert.equal(denied.status,403);await denied.arrayBuffer();
});
await fs.mkdir('docs/flutter-scene',{recursive:true});
await fs.writeFile('docs/flutter-scene/web-verification.json',JSON.stringify({origin:origin+'/scene/',checkedAt:new Date().toISOString(),passed:checks.length,checks,phonePerformanceVerified:false,recordingVerified:false},null,2)+'\n');
