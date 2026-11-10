import fs from 'node:fs';
import COS from 'cos-nodejs-sdk-v5';
import {credentials} from './tencent-speech.mjs';
let cache;
export async function curriculumMedia(){
 const file=new URL('../data/curriculum/audio-release.json',import.meta.url);
 if(!fs.existsSync(file))throw Object.assign(Error('正式声音尚未就绪'),{status:503});
 const release=JSON.parse(fs.readFileSync(file,'utf8'));
 const local=process.env.LOCAL_TEACHING_AUDIO==='1'?JSON.parse(fs.readFileSync(new URL('../data/curriculum/teaching-audio.json',import.meta.url),'utf8')):null;
 const id=release.id+(local?':'+local.id:'');
 if(cache?.id===id&&cache.expiresAt>Date.now()+300000)return cache;
 const cfg=JSON.parse(fs.readFileSync(new URL('../.secrets/cos-scene-assets.json',import.meta.url),'utf8')),c=credentials();
 const cos=new COS({SecretId:c.secretId,SecretKey:c.secretKey,Protocol:'https:'});
 const assets=await Promise.all(release.assets.map(a=>new Promise((resolve,reject)=>cos.getObjectUrl({Bucket:cfg.bucket,Region:cfg.region,Key:a.key,Sign:true,Expires:3300,Protocol:'https:'},(e,r)=>e?reject(e):resolve({...a,url:r.Url})))));
 if(local)assets.push(...local.assets.map(a=>({...a,url:`http://127.0.0.1:5296/api/local-preview/teaching/${a.id}.wav`})));
 return cache={id,expiresAt:Date.now()+3300000,assets};
}
