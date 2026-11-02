import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
import COS from 'cos-nodejs-sdk-v5';
import {validateRelease} from '../services/content-store.mjs';
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
const catalog=JSON.parse(await fs.readFile('data/course-catalog.json','utf8'));
if(catalog.courses.some(c=>c.id==='introductions-01-v1')){
 const quality=JSON.parse(await fs.readFile('data/curriculum/release-quality.json','utf8'));
 if(quality.schema!==1||quality.courseCount!==96||quality.categoryCount!==8||quality.editorial!=='second-pass-reviewed'||quality.catalogHash!==hash(await fs.readFile('data/course-catalog.json')))throw Error('Curriculum release review is missing or stale');
 for(const file of quality.files)if(hash(await fs.readFile(file.path))!==file.sha256)throw Error('Reviewed asset has changed: '+file.path);
}
const assets=[];
for(const folder of ['audio','images','courses']){
 for(const name of (await fs.readdir(`scene-preview/assets/avatar/${folder}`)).sort()){
  if(!/\.(wav|json|svg|txt)$/.test(name))continue;
  if(folder==='courses'&&!catalog.courses.some(c=>c.status==='published'&&name===c.asset+'.json'))continue;
  const asset=`assets/avatar/${folder}/${name}`,bytes=await fs.readFile('scene-preview/'+asset);
  assets.push({path:asset,size:bytes.length,sha256:hash(bytes)});
 }
}
const id=hash(JSON.stringify({catalog,assets}));
const release=validateRelease({schema:1,id,created:Date.now(),catalog,assets:assets.map(a=>({...a,key:`courses/releases/${id}/${a.path}`}))});
await fs.mkdir('work/course-release',{recursive:true});
await fs.writeFile('work/course-release/'+id+'.json',JSON.stringify(release,null,2));
if(!process.argv.includes('--upload')){console.log(`Prepared course release ${id}: ${assets.length} files. Use --upload to publish immutable objects.`);process.exit(0);}
const config=JSON.parse(await fs.readFile('.secrets/cos-scene-assets.json','utf8'));
const c=JSON.parse((await fs.readFile('.secrets/tencent.json','utf8')).replace(/^\uFEFF/,''));
const cos=new COS({SecretId:c.secretId,SecretKey:c.secretKey,Protocol:'https:',Timeout:60000});
const call=(method,params)=>new Promise((resolve,reject)=>cos[method]({Bucket:config.bucket,Region:config.region,...params},(e,r)=>e?reject(Error(`${method}: ${e.code||e.statusCode}`)):resolve(r)));
if((await call('getBucketAcl',{})).ACL!=='private')throw Error('Course bucket must be private');
let cursor=0;
await Promise.all(Array.from({length:6},async()=>{
 while(cursor<release.assets.length){const a=release.assets[cursor++],bytes=await fs.readFile('scene-preview/'+a.path);
  await call('putObject',{Key:a.key,Body:bytes,ContentType:{'.wav':'audio/wav','.json':'application/json','.svg':'image/svg+xml','.txt':'text/plain'}[path.extname(a.path)],CacheControl:'private, max-age=31536000, immutable',Headers:{'x-cos-server-side-encryption':'AES256'}});
  const stored=await call('getObject',{Key:a.key,DataType:'buffer'});if(hash(stored.Body)!==a.sha256)throw Error('Uploaded course object failed integrity check');
 }
}));
await fs.writeFile('work/course-release/staged.json',JSON.stringify(release,null,2));
console.log(`Verified ${release.assets.length} private COS objects. Staged release ${id}; activation is separate.`);
