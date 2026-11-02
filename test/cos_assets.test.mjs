import test from 'node:test';
import assert from 'node:assert/strict';
import {assetReadPolicy,assetHttp,createModelManifest} from '../services/cos-assets.mjs';

const config={region:'ap-beijing',appId:'123',bucket:'glb-123',prefix:'models/scene-storm/version',revision:'a'.repeat(64),size:4,chunkSize:4,parts:[{key:'models/scene-storm/version/part-0.bin',size:4,sha256:'b'.repeat(64)}]};
test('asset authorization grants only read access to the current model prefix',()=>{
  const policy=assetReadPolicy(config);
  assert.deepEqual(policy.statement[0].action,['name/cos:GetObject']);
  assert.deepEqual(policy.statement[0].resource,['qcs::cos:ap-beijing:uid/123:glb-123/models/scene-storm/version/*']);
});
test('current model manifest signs parts and preserves integrity metadata without exposing credentials',async()=>{
  const manifest=await createModelManifest(config,{tokenProvider:async()=>({Credentials:{TmpSecretId:'test-id',TmpSecretKey:'test-secret',Token:'test-token'}})});
  assert.equal(manifest.revision,config.revision);
  assert.equal(manifest.size,4);
  assert.equal(manifest.parts[0].sha256,config.parts[0].sha256);
  const url=new URL(manifest.parts[0].url);
  assert.equal(url.protocol,'https:');
  assert.equal(url.hostname,'glb-123.cos.ap-beijing.myqcloud.com');
  assert.equal(url.pathname,'/'+config.parts[0].key);
  assert.equal(JSON.stringify(manifest).includes('test-secret'),false);
});
test('current model endpoint rejects remote callers and the retired endpoint is absent',async()=>{
  let status;
  const res={writeHead:s=>{status=s;return res;},end:()=>{}};
  const req={socket:{remoteAddress:'10.0.0.1'},headers:{},method:'GET'};
  assert.equal(await assetHttp(req,res,new URL('http://localhost/api/assets/scene-manifest')),true);
  assert.equal(status,403);
  assert.equal(await assetHttp(req,res,new URL('http://localhost/api/assets/model-manifest')),false);
});
