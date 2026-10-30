import fs from 'node:fs';
import {spawnSync} from 'node:child_process';
function git(args,input){const r=spawnSync('git',args,{input,maxBuffer:128*1024*1024});if(r.status!==0)throw Error('Git index inspection failed');return r.stdout;}
const forbidden=[];
for(const file of fs.existsSync('.secrets') ? fs.readdirSync('.secrets') : []){
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
if(files.some(file=>/[\r\n]/.test(file)))throw Error('Ambiguous staged filename');
const objects=files.length?git(['cat-file','--batch'],files.map(file=>':'+file).join('\n')+'\n'):Buffer.alloc(0);
let cursor=0;
for(const file of files){
 if(/(^|\/)(\.secrets|node_modules|\.dart_tool|work|outputs)(\/|$)|\.(apk|aab|jks|keystore|p12|pem|key)$/.test(file))throw Error('Private or generated file staged: '+file);
 const lineEnd=objects.indexOf(10,cursor),header=objects.subarray(cursor,lineEnd).toString().split(' '),size=Number(header[2]);
 if(lineEnd<0||header[1]!=='blob'||!Number.isSafeInteger(size)||size<0)throw Error('Invalid Git index object');
 const start=lineEnd+1,end=start+size;if(end>=objects.length||objects[end]!==10)throw Error('Incomplete Git index object');
 const data=objects.subarray(start,end);cursor=end+1;bytes+=data.length;
 if(forbidden.some(secret=>data.includes(secret))||/-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----/.test(data.toString('utf8')))throw Error('Credential material detected in staged file: '+file);
 if(data.length>50*1024*1024)throw Error('Large non-LFS blob staged: '+file);
}
console.log(JSON.stringify({stagedFiles:files.length,stagedBytes:bytes,credentialScan:'passed',secretValuesPrinted:false}));
