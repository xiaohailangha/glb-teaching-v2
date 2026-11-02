import fs from 'node:fs/promises';
import path from 'node:path';
import {DatabaseSync,backup} from 'node:sqlite';
import {ContentStore} from '../services/content-store.mjs';
import {projectRoot,dataRoot} from '../services/storage-paths.mjs';
// One-time local migration. Existing destination databases are never overwritten.
async function exists(p){try{await fs.access(p);return true;}catch{return false;}}
for(const [old,name,db] of [['auth-private','auth','accounts.sqlite'],['learning-private','learning','learning.sqlite']]){
 const source=path.join(projectRoot,'work',old,db),target=path.join(dataRoot,name,db);
 if(await exists(target)||!await exists(source))continue;
 await fs.mkdir(path.dirname(target),{recursive:true,mode:0o700});
 const connection=new DatabaseSync(source,{readOnly:true});
 try{await backup(connection,target+'.tmp');}finally{connection.close();}
 const check=new DatabaseSync(target+'.tmp',{readOnly:true});
 try{if(check.prepare('PRAGMA quick_check').get().quick_check!=='ok')throw Error('Local database verification failed');}finally{check.close();}
 if(name==='auth')await fs.copyFile(path.join(projectRoot,'work',old,'encryption.key'),path.join(dataRoot,name,'encryption.key'));
 await fs.rename(target+'.tmp',target);
 console.log(`Local ${name} database snapshot verified; original retained.`);
}
const content=new ContentStore();
if(!content.state().active){
 const staged=path.join(projectRoot,'work/course-release/staged.json');
 if(!await exists(staged))throw Error('Prepare and upload a course release before starting the app.');
 const release=JSON.parse(await fs.readFile(staged,'utf8'));content.stage(release);content.activate(release.id,null);
 console.log('Local verified course release activated.');
}
