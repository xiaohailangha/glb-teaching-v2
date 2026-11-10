import fs from 'node:fs/promises';
import crypto from 'node:crypto';
import COS from 'cos-nodejs-sdk-v5';
import {credentials} from '../services/tencent-speech.mjs';
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
const sample=JSON.parse(await fs.readFile('data/curriculum/sample.json','utf8')),assets=[];
for(const a of sample.audio){const m=JSON.parse(await fs.readFile(`work/b101-audio/${a.id}.json`,'utf8')),wav=await fs.readFile(`work/b101-audio/${a.id}.wav`);if(m.text!==a.text||m.sha256!==hash(wav)||m.secondPass?.sha256!==m.sha256)throw Error('Audio not double-checked: '+a.id);assets.push({id:a.id,text:a.text,sha256:m.sha256,size:wav.length,duration:m.duration,cues:m.cues,wordTimings:m.wordTimings,quality:m.quality,secondPass:m.secondPass,phoneticAlias:m.phoneticAlias});}
const id=hash(JSON.stringify(assets));for(const a of assets)a.key=`courses/pilots/b101/${id}/${a.id}.wav`;
if(!process.argv.includes('--upload')){console.log(`Reviewed ${assets.length} recordings; --upload stores immutable private COS objects.`);process.exit(0);}
const config=JSON.parse(await fs.readFile('.secrets/cos-scene-assets.json','utf8')),c=credentials(),cos=new COS({SecretId:c.secretId,SecretKey:c.secretKey,Protocol:'https:'});
const call=(method,args)=>new Promise((resolve,reject)=>cos[method]({Bucket:config.bucket,Region:config.region,...args},(e,r)=>e?reject(Error(e.code||'COS request failed')):resolve(r)));
if((await call('getBucketAcl',{})).ACL!=='private')throw Error('Private COS required');
for(const a of assets){await call('putObject',{Key:a.key,Body:await fs.readFile(`work/b101-audio/${a.id}.wav`),ContentType:'audio/wav',CacheControl:'private, max-age=31536000, immutable',Headers:{'x-cos-server-side-encryption':'AES256'}});if(hash((await call('getObject',{Key:a.key,DataType:'buffer'})).Body)!==a.sha256)throw Error('COS integrity mismatch '+a.id);}
await fs.writeFile('data/curriculum/audio-release.json',JSON.stringify({schema:1,id,created:Date.now(),assets},null,2));console.log(`Verified ${assets.length} private COS recordings. Media release ${id}.`);
