// Upload only the new renderer's immutable model chunks into the existing
// private project bucket. Does not change the original model or bucket policy.
import COS from 'cos-nodejs-sdk-v5';
import fs from 'node:fs/promises';
import crypto from 'node:crypto';
import {gzipSync} from 'node:zlib';

const credentials=JSON.parse((await fs.readFile('.secrets/tencent.json','utf8')).replace(/^\uFEFF/,''));
const base=JSON.parse(await fs.readFile('.secrets/cos-assets.json','utf8'));
const cos=new COS({SecretId:credentials.secretId,SecretKey:credentials.secretKey,Protocol:'https:',Timeout:60000});
const call=(method,params)=>new Promise((resolve,reject)=>cos[method](params,(error,result)=>error?reject(Error(`${method}: ${error.code||error.statusCode}`)):resolve(result)));
const params={Bucket:base.bucket,Region:base.region};
if((await call('getBucketAcl',params)).ACL!=='private')throw Error('Project bucket must stay private.');
const directory='scene-preview/build/web/assets/flutter_scene_generated/';
const manifest=JSON.parse(await fs.readFile(directory+'manifest.json','utf8'));
const entry=manifest.entries.find(e=>e.source==='assets/avatar/models/storm-performance.glb');
if(!entry||!/^scene\.storm-performance\.[a-f0-9]+\.fsceneb$/.test(entry.file))throw Error('Build the scene preview first.');
const content=await fs.readFile(directory+entry.file);
const revision=crypto.createHash('sha256').update(content).digest('hex'),chunkSize=1048576;
const prefix=`models/scene-storm/${revision}`,parts=[];
let next=0,storedBytes=0,completed=0;
async function worker(){
 while(next<Math.ceil(content.length/chunkSize)){
  const index=next++,part=content.subarray(index*chunkSize,Math.min(content.length,(index+1)*chunkSize));
  const sha256=crypto.createHash('sha256').update(part).digest('hex'),Key=`${prefix}/part-${index}.bin`,compressed=gzipSync(part,{level:5});
  await call('putObject',{...params,Key,Body:compressed,ContentLength:compressed.length,ContentType:'application/octet-stream',ContentEncoding:'gzip',CacheControl:'private, max-age=86400',StorageClass:'STANDARD',Headers:{'x-cos-meta-sha256':sha256,'x-cos-server-side-encryption':'AES256'}});
  storedBytes+=compressed.length;parts[index]={key:Key,size:part.length,sha256};completed++;
  if(completed%20===0)console.log(`Scene model uploaded: ${completed} parts`);
 }
}
await Promise.all(Array.from({length:6},worker));
const config={bucket:base.bucket,region:base.region,appId:base.appId,prefix,revision,size:content.length,chunkSize,parts,asset:entry.file};
await fs.writeFile('.secrets/cos-scene-assets.json',JSON.stringify(config,null,2));
console.log(JSON.stringify({modelBytes:content.length,compressedBytes:storedBytes,parts:parts.length,revision,acl:'private'}));
