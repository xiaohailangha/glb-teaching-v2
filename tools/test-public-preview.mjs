import fs from 'node:fs';
import assert from 'node:assert/strict';
const origin=fs.readFileSync(new URL('../work/tunnel/public-origin.txt',import.meta.url),'utf8').trim();
const {token}=JSON.parse(fs.readFileSync(new URL('../work/tunnel/session.json',import.meta.url),'utf8'));
const request=(path,options={})=>fetch(origin+path,{...options,signal:AbortSignal.timeout(60000)});
let response=await request('/');assert.equal(response.status,403);
response=await request('/enter?key=invalid',{redirect:'manual'});assert.equal(response.status,403);
response=await request('/enter?key='+token,{redirect:'manual'});assert.equal(response.status,303);
const cookie=response.headers.get('set-cookie');assert.match(cookie,/Secure/);assert.match(cookie,/HttpOnly/);
const headers={cookie:cookie.split(';')[0]};
response=await request('/',{headers});assert.equal(response.status,200);assert.match(await response.text(),/rotate-device/);
response=await request('/api/speech/status',{headers});assert.equal(response.status,200);assert.equal((await response.json()).configured,true);
for(const path of ['/health','/benchmark','/.secrets/tencent.json','/tools/public-preview.mjs','/api/speech/unknown']){
  response=await request(path,{headers});assert.ok([403,404].includes(response.status),path);
}
response=await request('/api/speech/tts',{method:'POST',headers:{...headers,origin:'https://untrusted.invalid','content-type':'application/json'},body:'{}'});assert.equal(response.status,403);
response=await request('/api/speech/tts',{method:'POST',headers:{...headers,origin,'content-type':'application/json'},body:JSON.stringify({text:'apple',voice:403007,speed:0,language:'en'})});
assert.equal(response.status,200);const speech=await response.json();assert.equal(speech.usable,true);assert.ok(speech.cues.length>0);
for(const path of ['/api/speech/assess?text=apple','/api/speech/recognize']){
  response=await request(path,{method:'POST',headers:{...headers,origin,'content-type':'audio/wav'},body:'invalid'});
  assert.equal(response.status,400); // Reached validation, not a paid recognition request.
}
response=await request('/assets/assets/avatar/models/storm-performance.glb',{headers:{...headers,range:'bytes=0-31'}});
assert.equal(response.status,206);assert.equal((await response.arrayBuffer()).byteLength,32);
console.log('HTTPS auth, page, model Range and Tencent TTS: PASS; recording validation reachable; secrets, diagnostics and foreign origins denied.');
