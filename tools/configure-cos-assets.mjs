import COS from 'cos-nodejs-sdk-v5';
import fs from 'node:fs/promises';
import crypto from 'node:crypto';
import {gzipSync} from 'node:zlib';
const root=new URL('../',import.meta.url);
const credentials=JSON.parse((await fs.readFile(new URL('.secrets/tencent.json',root),'utf8')).replace(/^\uFEFF/,''));
const cos=new COS({SecretId:credentials.secretId,SecretKey:credentials.secretKey,Protocol:'https:',Timeout:60000});
const call=(name,p)=>new Promise((resolve,reject)=>cos[name](p,(e,r)=>e?reject(Error(`${name}: ${e.code||e.statusCode} ${e.message||''}`)):resolve(r)));
const buckets=await call('getService',{});
console.log(JSON.stringify({buckets:buckets.Buckets?.map(b=>({name:b.Name,region:b.Location}))||[]}));
if(process.argv[2]!=='configure')process.exit(0);
const Bucket=`glb-teaching-assets-${credentials.appId}`,Region='ap-beijing',params={Bucket,Region};
const existing=buckets.Buckets?.find(b=>b.Name===Bucket);
if(existing&&existing.Location!==Region)throw Error('Existing project bucket has a different region; no change made.');
if(!existing)await call('putBucket',{...params,ACL:'private'});
const acl=await call('getBucketAcl',params);
if(acl.ACL&&acl.ACL!=='private')throw Error('Project bucket is not private; inspect before changing permissions.');
await call('putBucketCors',{...params,CORSRules:[{ID:'glb-private-preview',AllowedOrigins:['https://49.233.179.83'],AllowedMethods:['GET','HEAD'],AllowedHeaders:['Range'],ExposeHeaders:['ETag','Content-Length','Content-Encoding','Content-Range','x-cos-meta-sha256'],MaxAgeSeconds:600}]});
const file=await fs.open(new URL('assets/avatar/models/storm-performance.glb',root),'r');
const size=(await file.stat()).size,chunkSize=1048576;
const revision=crypto.createHash('sha256').update(await fs.readFile(new URL('assets/avatar/models/storm-performance.glb',root))).digest('hex');
const prefix=`models/storm/${revision}`;
const parts=[];let storedBytes=0,next=0,done=0;
async function worker(){
 while(next<Math.ceil(size/chunkSize)){
  const index=next++,buffer=Buffer.alloc(Math.min(chunkSize,size-index*chunkSize));
  let offset=0;while(offset<buffer.length){const {bytesRead}=await file.read(buffer,offset,buffer.length-offset,index*chunkSize+offset);if(!bytesRead)throw Error('Incomplete source model');offset+=bytesRead;}
  const sha256=crypto.createHash('sha256').update(buffer).digest('hex'),Key=`${prefix}/part-${index}.bin`,compressed=gzipSync(buffer,{level:5});
  await call('putObject',{...params,Key,Body:compressed,ContentLength:compressed.length,ContentType:'application/octet-stream',ContentEncoding:'gzip',CacheControl:'private, max-age=86400',ContentDisposition:'attachment',StorageClass:'STANDARD',Headers:{'x-cos-meta-sha256':sha256,'x-cos-server-side-encryption':'AES256'}});
  storedBytes+=compressed.length;parts[index]={key:Key,size:buffer.length,sha256};done++;
  if(done%30===0)console.log(`Uploaded ${done} model parts`);
 }
}
try{await Promise.all(Array.from({length:6},worker));}finally{await file.close();}
const config={bucket:Bucket,region:Region,appId:String(credentials.appId),prefix,revision,size,chunkSize,parts};
await fs.writeFile(new URL('.secrets/cos-assets.json',root),JSON.stringify(config,null,2));
await call('putObject',{...params,Key:`${prefix}/manifest.json`,Body:Buffer.from(JSON.stringify({revision,size,chunkSize,parts})),ContentType:'application/json',StorageClass:'STANDARD'});
const check=await call('getBucketAcl',params),cors=await call('getBucketCors',params);
console.log(JSON.stringify({bucket:Bucket,region:Region,acl:check.ACL,cors:cors.CORSRules,objects:parts.length+1,storedBytes,revision}));
