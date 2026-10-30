import fs from 'node:fs';
import {spawnSync} from 'node:child_process';
function git(args){const r=spawnSync('git',args,{maxBuffer:64*1024*1024});if(r.status!==0)throw Error('Git index inspection failed');return r.stdout;}
const forbidden=[];
for(const file of fs.readdirSync('.secrets')){
 if(!file.endsWith('.json'))continue;
 try{
  const visit=(value,key='')=>{
   if(typeof value==='string'&&/secret(id|key)|password|token|private.?key/i.test(key)&&value.length>=12)forbidden.push(Buffer.from(value));
   else if(value&&typeof value==='object')for(const [k,v]of Object.entries(value))visit(v,k);
  };
  visit(JSON.parse(fs.readFileSync('.secrets/'+file,'utf8').replace(/^\uFEFF/,'')));
 }catch{/* Non-JSON local credentials are excluded by path and private-key markers. */}
}
const files=git(['diff','--cached','--name-only','--diff-filter=ACMR','-z']).toString('utf8').split('\0').filter(Boolean);
let bytes=0;
for(const file of files){
 if(/(^|\/)(\.secrets|node_modules|\.dart_tool|work|outputs)(\/|$)|\.(apk|aab|jks|keystore|p12|pem|key)$/.test(file))throw Error('Private or generated file staged: '+file);
 const data=git(['show',':'+file]);bytes+=data.length;
 if(forbidden.some(secret=>data.includes(secret))||/-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----/.test(data.toString('utf8')))throw Error('Credential material detected in staged file: '+file);
 if(data.length>50*1024*1024)throw Error('Large non-LFS blob staged: '+file);
}
console.log(JSON.stringify({stagedFiles:files.length,stagedBytes:bytes,credentialScan:'passed',secretValuesPrinted:false}));
