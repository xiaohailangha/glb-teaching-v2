import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import crypto from 'node:crypto';
import {DatabaseSync,backup} from 'node:sqlite';
import COS from 'cos-nodejs-sdk-v5';
import {sealBackup,openBackup} from '../services/backup-codec.mjs';
import {projectRoot,dataRoot,authDirectory,learningDirectory} from '../services/storage-paths.mjs';
import {credentials} from '../services/tencent-speech.mjs';

const config=JSON.parse(await fs.readFile(path.join(projectRoot,'.secrets/backup-cos.json'),'utf8'));
const key=await fs.readFile(path.join(projectRoot,'.secrets/project-backup.key'));
const c=credentials(),cos=new COS({SecretId:c.secretId,SecretKey:c.secretKey,Protocol:'https:',Timeout:90000});
const call=(method,params)=>new Promise((resolve,reject)=>cos[method]({Bucket:config.bucket,Region:config.region,...params},(e,r)=>e?reject(Error(`${method}: ${e.code||e.statusCode}`)):resolve(r)));
const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const temp=await fs.mkdtemp(path.join(os.tmpdir(),'snow-backup-'));await fs.chmod(temp,0o700);
const statusFile=path.join(dataRoot,'backup-status.json');let status={};try{status=JSON.parse(await fs.readFile(statusFile,'utf8'));}catch{}
async function saveStatus(){await fs.writeFile(statusFile,JSON.stringify(status,null,2),{mode:0o600});if(process.platform!=='win32'){const owner=await fs.stat(dataRoot);await fs.chown(statusFile,owner.uid,owner.gid);}}
async function snapshot(source,name){const db=new DatabaseSync(source,{readOnly:true});try{await backup(db,path.join(temp,name));}finally{db.close();}return fs.readFile(path.join(temp,name));}
async function verify(payload){
 const archive=JSON.parse(payload);if(archive.schema!==2||!Array.isArray(archive.files))throw Error('Invalid archive');
 const seen=new Set();
 for(const file of archive.files){if(!/^[a-zA-Z0-9_.\/-]+$/.test(file.name)||file.name.includes('..')||file.name.startsWith('/')||seen.has(file.name))throw Error('Unsafe backup entry');seen.add(file.name);
  const bytes=Buffer.from(file.data,'base64');if(sha(bytes)!==file.sha256)throw Error('Backup hash mismatch');
  if(file.name.endsWith('.sqlite')){const target=path.join(temp,'verify-'+path.basename(file.name));await fs.writeFile(target,bytes,{mode:0o600});const db=new DatabaseSync(target,{readOnly:true});try{if(db.prepare('PRAGMA quick_check').get().quick_check!=='ok')throw Error('Backup database integrity failed');const tables=db.prepare("SELECT name FROM sqlite_master WHERE type='table'").all().map(r=>r.name);for(const t of file.tables||[])if(!tables.includes(t))throw Error('Backup database table missing');}finally{db.close();}}
 }
 for(const required of ['auth/accounts.sqlite','auth/encryption.key','learning/learning.sqlite','admin/management.sqlite','curriculum/cloud-runtime/current.json'])if(!seen.has(required))throw Error('Incomplete project backup');
 const current=JSON.parse(Buffer.from(archive.files.find(f=>f.name==='curriculum/cloud-runtime/current.json').data,'base64'));
 const indexEntry=archive.files.find(f=>f.name===`curriculum/cloud-runtime/releases/${current.release}/index.json`);
 if(!indexEntry||indexEntry.sha256!==current.release)throw Error('Formal curriculum index missing');
 const index=JSON.parse(Buffer.from(indexEntry.data,'base64'));
 if(index.catalog.courses.length!==555)throw Error('Formal curriculum incomplete');
 for(const [id,d] of Object.entries(index.lessons))for(const name of [`teacher/${id}.json`,d.path])if(!seen.has(`curriculum/cloud-runtime/releases/${current.release}/${name}`))throw Error('Formal lesson missing');
 return archive;
}
try{
 if((await call('getBucketAcl',{})).ACL!=='private')throw Error('Backup bucket must be private');
 if(process.argv.includes('--verify-latest')){
  if(!status.object)throw Error('No cloud backup recorded');const download=await call('getObject',{Key:status.object,DataType:'buffer'});await verify(openBackup(download.Body,key));status.verifiedAt=Date.now();status.error=null;
 }else{
  const files=[];const add=(name,bytes,tables)=>files.push({name,data:bytes.toString('base64'),sha256:sha(bytes),...(tables?{tables}:{})});
  // Snapshot learning first, then identity, so newly created learner IDs can resolve.
  add('learning/learning.sqlite',await snapshot(path.join(learningDirectory,'learning.sqlite'),'learning.sqlite'),['activity','events','checkpoints']);
  add('auth/accounts.sqlite',await snapshot(path.join(authDirectory,'accounts.sqlite'),'accounts.sqlite'),['users','sessions']);
  add('auth/encryption.key',await fs.readFile(path.join(authDirectory,'encryption.key')));
  const adminRoot=process.env.SNOW_ADMIN_DATA_DIR||'/var/lib/snow-speaks-admin';
  add('admin/management.sqlite',await snapshot(path.join(adminRoot,'management/management.sqlite'),'management.sqlite'),['admins','audit']);
  const formal=path.join(projectRoot,'data/curriculum/cloud-runtime'),current=await fs.readFile(path.join(formal,'current.json'));
  add('curriculum/cloud-runtime/current.json',current);
  const release=JSON.parse(current).release;if(!/^[a-f0-9]{64}$/.test(release))throw Error('Invalid formal release');
  const releaseDir=path.join(formal,'releases',release),indexBytes=await fs.readFile(path.join(releaseDir,'index.json')),index=JSON.parse(indexBytes);
  add(`curriculum/cloud-runtime/releases/${release}/index.json`,indexBytes);
  for(const [id,d] of Object.entries(index.lessons))for(const name of [`teacher/${id}.json`,d.path])add(`curriculum/cloud-runtime/releases/${release}/${name}`,await fs.readFile(path.join(releaseDir,name)));
  const created=Date.now(),payload=Buffer.from(JSON.stringify({schema:2,created,files}));await verify(payload);
  const encrypted=sealBackup(payload,key),object='daily/'+new Date(created).toISOString().replace(/[:.]/g,'-')+'.enc';
  await call('putObject',{Key:object,Body:encrypted,ContentType:'application/octet-stream',Headers:{'x-cos-server-side-encryption':'AES256'}});
  const stored=await call('getObject',{Key:object,DataType:'buffer'});if(sha(stored.Body)!==sha(encrypted))throw Error('Cloud backup differs');await verify(openBackup(stored.Body,key));
  status={lastSuccess:created,verifiedAt:Date.now(),object,bytes:encrypted.length,region:config.region,retentionDays:30,error:null};
 }
 await saveStatus();
 console.log('Encrypted cloud backup downloaded, decrypted and database integrity verified.');
}catch(error){status.error='云备份或恢复校验失败，请检查备份任务';await saveStatus();throw error;}
finally{await fs.rm(temp,{recursive:true,force:true});}
