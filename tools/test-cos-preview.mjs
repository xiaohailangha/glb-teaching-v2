import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {credentials} from '../services/tencent-speech.mjs';
const c=JSON.parse(await fs.readFile(new URL('../.secrets/cloud-preview.json',import.meta.url),'utf8'));
const config=JSON.parse(await fs.readFile(new URL('../.secrets/cos-assets.json',import.meta.url),'utf8'));
const authHeaders=c.accessMode==='public'?{}:{Authorization:'Basic '+Buffer.from(c.username+':'+c.password).toString('base64')};
const endpoint=c.origin+'/api/assets/model-manifest';
const checks=[];
async function test(name,fn){await fn();checks.push({name,ok:true});console.log('PASS '+name);}
let manifest;
await test('manifest follows configured preview access mode',async()=>{const r=await fetch(endpoint);assert.equal(r.status,c.accessMode==='public'?200:401);await r.arrayBuffer();});
await test('manifest exposes only scoped temporary downloads',async()=>{
 const r=await fetch(endpoint,{headers:authHeaders});assert.equal(r.status,200);
 manifest=await r.json();assert.equal(manifest.parts.length,147);assert.equal(manifest.revision,config.revision);
 const serialized=JSON.stringify(manifest),master=credentials();assert.ok(!/secretKey|TmpSecretKey/.test(serialized));
 assert.ok(!serialized.includes(master.secretId));assert.ok(!serialized.includes(master.secretKey));
 assert.ok(manifest.expiresAt>Date.now());
 for(const p of manifest.parts){const u=new URL(p.url);assert.equal(u.hostname,config.bucket+'.cos.'+config.region+'.myqcloud.com');assert.ok(u.searchParams.get('x-cos-security-token'));}
});
await test('objects are private without a signature',async()=>{
 const u=new URL(manifest.parts[0].url);u.search='';assert.equal((await fetch(u)).status,403);
});
await test('CORS allows the actual preview origin with matching decompressed bytes',async()=>{
 for(const index of [0,manifest.parts.length-1]){
 const p=manifest.parts[index],r=await fetch(p.url,{headers:{Origin:c.origin}});assert.equal(r.status,200);
 assert.equal(r.headers.get('access-control-allow-origin'),c.origin);assert.equal(r.headers.get('content-encoding'),'gzip');
 const b=Buffer.from(await r.arrayBuffer());assert.equal(b.length,p.size);assert.equal(createHash('sha256').update(b).digest('hex'),p.sha256);
 }
});
await test('other origins cannot get cross-origin read permission',async()=>{
 const r=await fetch(manifest.parts[0].url,{method:'OPTIONS',headers:{Origin:'https://example.org','Access-Control-Request-Method':'GET'}});
 assert.notEqual(r.headers.get('access-control-allow-origin'),'https://example.org');assert.notEqual(r.headers.get('access-control-allow-origin'),'*');
});
const report={at:new Date().toISOString(),origin:c.origin,bucket:config.bucket,region:config.region,checks,parts:manifest.parts.length,bytes:manifest.size};
await fs.mkdir(new URL('../docs/cos-integration/',import.meta.url),{recursive:true});
await fs.writeFile(new URL('../docs/cos-integration/latest-verification.json',import.meta.url),JSON.stringify(report,null,2));
console.log('COS public verification complete.');
