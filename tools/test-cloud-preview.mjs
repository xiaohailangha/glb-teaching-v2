import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
const c=JSON.parse(await fs.readFile(new URL('../.secrets/cloud-preview.json',import.meta.url),'utf8'));
const base=c.origin,authHeaders=c.accessMode==='public'?{}:{Authorization:'Basic '+Buffer.from(c.username+':'+c.password).toString('base64')};
const report={at:new Date().toISOString(),origin:base,checks:[]};
async function request(p,opts={}){return fetch(base+p,{...opts,headers:{...authHeaders,...opts.headers},signal:AbortSignal.timeout(120000)});}
async function test(name,fn){await fn();report.checks.push({name,ok:true});console.log('PASS '+name);}
await test('TLS trusted and page follows configured access mode',async()=>{const r=await fetch(base,{signal:AbortSignal.timeout(15000)});assert.equal(r.status,c.accessMode==='public'?200:401);await r.arrayBuffer();});
await test('opening a shared link is allowed but cross-site POST is blocked',async()=>{
 const r=await request('/',{headers:{'Sec-Fetch-Site':'cross-site'}});assert.equal(r.status,200);await r.arrayBuffer();
 const p=await request('/api/speech/tts',{method:'POST',headers:{'Sec-Fetch-Site':'cross-site','Content-Type':'application/json'},body:'{"text":"apple"}'});assert.equal(p.status,403);
});
await test('Flutter release and avatar page accessible',async()=>{
 for(const p of ['/','/main.dart.js','/assets/assets/avatar/index.html']){const r=await request(p);assert.equal(r.status,200);await r.arrayBuffer();}
});
await test('source credentials and diagnostics unavailable',async()=>{
 for(const p of ['/.secrets/tencent.json','/server.mjs','/services/tencent-speech.mjs','/benchmark','/performance-recording'])assert.ok([403,404].includes((await request(p)).status));
});
await test('cross-origin paid requests rejected',async()=>{assert.equal((await request('/api/speech/tts',{method:'POST',headers:{Origin:'https://example.org','Content-Type':'application/json'},body:'{"text":"apple"}'})).status,403);});
await test('speech credentials configured only at backend',async()=>{
 const r=await request('/api/speech/status');assert.equal(r.status,200);const data=await r.json();assert.equal(data.configured,true);assert.ok(!JSON.stringify(data).match(/secretKey|secretId/));report.speech=data.versions;
});
const model='/assets/assets/avatar/models/storm-performance.glb';
await test('model chunks use consistent revision and exact bytes',async()=>{
 const h=await request(model,{method:'HEAD'});assert.equal(h.status,200);
 const size=Number(h.headers.get('X-Preview-Model-Bytes')),chunk=Number(h.headers.get('X-Preview-Chunk-Size')),etag=h.headers.get('ETag');
 assert.equal(chunk,1048576);assert.ok(size>100000000);assert.ok(etag);
 const file=await fs.open(new URL('../build/web'+model,import.meta.url),'r');
 try{for(const index of [0,Math.ceil(size/chunk)-1]){
 const r=await request(model+'?previewPart='+index);assert.equal(r.status,200);assert.equal(r.headers.get('X-Preview-Model-ETag'),etag);
 const body=Buffer.from(await r.arrayBuffer()),expected=Buffer.alloc(Math.min(chunk,size-index*chunk));await file.read(expected,0,expected.length,index*chunk);assert.deepEqual(body,expected);
 }}finally{await file.close();}
 report.model={bytes:size,chunk,etag};
});
await test('invalid model part rejected',async()=>{assert.equal((await request(model+'?previewPart=999')).status,404);});
await test('malformed recording fails without spending assessment call',async()=>{const r=await request('/api/speech/assess?text=apple',{method:'POST',headers:{Origin:base,'Content-Type':'audio/wav'},body:new Uint8Array([1,2,3])});assert.equal(r.status,400);});
await test('real cloud teaching audio and phoneme timeline',async()=>{
 const r=await request('/api/speech/tts',{method:'POST',headers:{Origin:base,'Content-Type':'application/json'},body:JSON.stringify({text:'apple',language:'en',voice:403007,speed:0})});
 const data=await r.json();assert.equal(r.status,200,JSON.stringify(data));assert.equal(data.usable,true);assert.ok(data.cues.length>0);report.tts={cues:data.cues.length,fields:Object.keys(data)};
 const audioPath=data.url||data.audioUrl||data.audio;assert.equal(typeof audioPath,'string');assert.ok(audioPath.startsWith('/api/speech/audio/'));
 const a=await request(audioPath);assert.equal(a.status,200);assert.equal(Buffer.from(await a.arrayBuffer()).toString('ascii',0,4),'RIFF');
});
if(process.argv.includes('--speech')){
 const r=await request('/api/speech/tts',{method:'POST',headers:{Origin:base,'Content-Type':'application/json'},body:JSON.stringify({text:'I like apples.',language:'en',voice:403007,speed:0})});
 const item=await r.json();assert.equal(r.status,200);assert.equal(item.usable,true);
 const wav=await (await request(item.audioUrl)).arrayBuffer();
 await test('real ASR through cloud server using synthetic sentence',async()=>{
   const result=await request('/api/speech/recognize',{method:'POST',headers:{Origin:base,'Content-Type':'audio/wav'},body:wav});
   const value=await result.json();assert.equal(result.status,200,JSON.stringify(value));assert.match(value.text,/apple/i);report.asr=value;
 });
 await test('real assessment through cloud server using synthetic sentence',async()=>{
   const result=await request('/api/speech/assess?text=I%20like%20apples.',{method:'POST',headers:{Origin:base,'Content-Type':'audio/wav'},body:wav});
   const value=await result.json();assert.equal(result.status,200,JSON.stringify(value));assert.ok(value.result.Words.length>0);report.assessment={words:value.result.Words.length,syntheticOnly:true};
 });
}
await fs.mkdir(new URL('../docs/cloud-deployment/',import.meta.url),{recursive:true});
await fs.writeFile(new URL('../docs/cloud-deployment/latest-verification.json',import.meta.url),JSON.stringify(report,null,2));
await fs.writeFile(new URL('../docs/cloud-deployment/'+report.at.replace(/[:.]/g,'-')+'.json',import.meta.url),JSON.stringify(report,null,2));
console.log('All public cloud checks passed.');
