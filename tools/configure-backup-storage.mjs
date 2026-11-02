import fs from 'node:fs/promises';
import crypto from 'node:crypto';
import COS from 'cos-nodejs-sdk-v5';
const c=JSON.parse((await fs.readFile('.secrets/tencent.json','utf8')).replace(/^\uFEFF/,''));
const config={bucket:`snow-speaks-backups-${c.appId}`,region:'ap-guangzhou'};
const cos=new COS({SecretId:c.secretId,SecretKey:c.secretKey,Protocol:'https:',Timeout:60000});
const call=(method,params={})=>new Promise((resolve,reject)=>cos[method]({Bucket:config.bucket,Region:config.region,...params},(e,r)=>e?reject(e):resolve(r)));
try{const acl=await call('getBucketAcl');if(acl.ACL!=='private')throw Error('Existing backup bucket is not private');}catch(e){if(e.statusCode!==404)throw e;try{await call('putBucket',{ACL:'private'});}catch(createError){if(createError.code!=='BucketAlreadyOwnedByYou')throw createError;}}
for(let attempt=0;;attempt++){try{if((await call('getBucketAcl')).ACL!=='private')throw Error('Backup bucket must remain private');break;}catch(e){if(e.statusCode!==404||attempt===14)throw e;await new Promise(resolve=>setTimeout(resolve,2000));}}
await call('putBucketEncryption',{ServerSideEncryptionConfiguration:{Rule:[{ApplySideEncryptionConfiguration:{SSEAlgorithm:'AES256'}}]}});
await call('putBucketVersioning',{VersioningConfiguration:{Status:'Enabled'}});
await call('putBucketLifecycle',{Rules:[{ID:'snow-daily-30-days',Status:'Enabled',Filter:{Prefix:'daily/'},Expiration:{Days:30},NoncurrentVersionExpiration:{NoncurrentDays:30},AbortIncompleteMultipartUpload:{DaysAfterInitiation:1}}]});
await fs.writeFile('.secrets/backup-cos.json',JSON.stringify(config,null,2));
try{await fs.writeFile('.secrets/project-backup.key',crypto.randomBytes(32),{flag:'wx',mode:0o600});}catch(e){if(e.code!=='EEXIST')throw e;}
if((await fs.readFile('.secrets/project-backup.key')).length!==32)throw Error('Invalid existing backup encryption key');
console.log('Independent private backup bucket configured in Guangzhou; daily archives retained for 30 days. Encryption key retained separately in local private configuration.');
