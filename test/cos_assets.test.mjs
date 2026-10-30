import test from 'node:test';
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import {downloadCloudModel,validateCloudManifest} from '../assets/avatar/cos-model-download.js';
import {downloadModel} from '../assets/avatar/model-download.js';
import {assetReadPolicy,assetHttp} from '../services/cos-assets.mjs';
const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
function fixture(){
 const source=Uint8Array.from({length:3100},(_,i)=>i%251),chunkSize=1024;
 const parts=Array.from({length:4},(_,i)=>{const b=source.slice(i*chunkSize,(i+1)*chunkSize);return {url:`https://glb-test-123.cos.ap-beijing.myqcloud.com/part-${i}?signature=one`,size:b.length,sha256:sha(b)};});
 return {source,manifest:{version:1,revision:sha(source),size:source.length,chunkSize,parts}};
}
function memoryCache(){const entries=new Map();return {open:async()=>({match:async k=>entries.get(k)?.clone(),put:async(k,v)=>entries.set(k,v.clone())}),keys:async()=>[],delete:async()=>true};}
test('COS parts reconstruct exact model; cached bytes survive expiring signed URLs',async()=>{
 const {source,manifest}=fixture(),cacheStorage=memoryCache();let calls=0;
 const fetchImpl=async url=>{calls++;const i=Number(new URL(url).pathname.match(/part-(\d+)/)[1]);return new Response(source.slice(i*1024,(i+1)*1024));};
 assert.deepEqual(new Uint8Array(await downloadCloudModel(manifest,{fetchImpl,cacheStorage})),source);assert.equal(calls,4);
 const renewed={...manifest,parts:manifest.parts.map(p=>({...p,url:p.url.replace('one','two')}))};
 assert.deepEqual(new Uint8Array(await downloadCloudModel(renewed,{fetchImpl,cacheStorage})),source);assert.equal(calls,4);
});
test('COS corrupt downloads are rejected and cannot become cached teaching assets',async()=>{
 const {manifest}=fixture();await assert.rejects(downloadCloudModel(manifest,{cacheStorage:memoryCache(),fetchImpl:async()=>new Response(new Uint8Array(1024))}),/integrity/);
});
test('denied browser storage does not prevent the model loading',async()=>{
 const {source,manifest}=fixture();const result=await downloadCloudModel(manifest,{cacheStorage:{open:async()=>{throw Error('quota');}},fetchImpl:async url=>{const i=Number(new URL(url).pathname.match(/part-(\d+)/)[1]);return new Response(source.slice(i*1024,(i+1)*1024));}});assert.deepEqual(new Uint8Array(result),source);
});
test('unavailable cloud manifest falls back to bundled model path',async()=>{
 let calls=[];const bytes=new Uint8Array([1,2,3]);
 const result=await downloadModel('/model.glb',{cloudManifestUrl:'/api/assets/model-manifest',fetchImpl:async(url,o)=>{calls.push(url);return url.includes('manifest')||o?.method==='HEAD'?new Response(null,{status:404}):new Response(bytes);}});
 assert.deepEqual(new Uint8Array(result),bytes);assert.deepEqual(calls,['/api/assets/model-manifest','/model.glb','/model.glb']);
});
test('manifest only accepts bounded models and HTTPS COS objects',()=>{
 const {manifest}=fixture();assert.throws(()=>validateCloudManifest({...manifest,size:300*1024*1024}));
 assert.throws(()=>validateCloudManifest({...manifest,parts:manifest.parts.map(p=>({...p,url:'https://evil.example/file'}))}));
});
test('asset authorization only grants this version read access; remote request denied',async()=>{
 const policy=assetReadPolicy({region:'ap-beijing',appId:'123',bucket:'glb-123',prefix:'models/storm/version'});
 assert.deepEqual(policy.statement[0].action,['name/cos:GetObject']);assert.deepEqual(policy.statement[0].resource,['qcs::cos:ap-beijing:uid/123:glb-123/models/storm/version/*']);
 let status;const res={writeHead:s=>{status=s;return res;},end:()=>{}};
 await assetHttp({socket:{remoteAddress:'10.0.0.1'},headers:{},method:'GET'},res,new URL('http://localhost/api/assets/model-manifest'));assert.equal(status,403);
});
