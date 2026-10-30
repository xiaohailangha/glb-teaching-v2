import fs from 'node:fs/promises';
import crypto from 'node:crypto';
import {spawn} from 'node:child_process';
import {api} from './tencent-deploy-api.mjs';
const instance='lhins-52h0i09a',host='49.233.179.83',label='glb-scene-apk-upload-20261030';
const name='glb-scene-0.2.0-r5-arm64.apk',file=`outputs/android-scene/${name}`;
const bytes=await fs.readFile(file),hash=crypto.createHash('sha256').update(bytes).digest('hex');
const verification=JSON.parse((await fs.readFile('outputs/android-scene/verification.json','utf8')).replace(/^\uFEFF/,''));
if(hash!==verification.sha256||!verification.signatureVerified)throw Error('APK verification mismatch');
async function run(source,name){
 const request=await api('tat','RunCommand',{InstanceIds:[instance],CommandName:name,CommandType:'SHELL',Content:Buffer.from(source).toString('base64'),SaveCommand:false,Timeout:120,Username:'root'});
 for(let i=0;i<55;i++){
  await new Promise(resolve=>setTimeout(resolve,2000));
  const result=await api('tat','DescribeInvocationTasks',{Filters:[{Name:'invocation-id',Values:[request.InvocationId]}],HideOutput:false});
  const task=result.InvocationTaskSet?.[0];if(!task)continue;
  if(task.TaskStatus==='SUCCESS')return Buffer.from(task.TaskResult?.Output||'','base64').toString();
  if(['FAILED','TIMEOUT','CANCELLED'].includes(task.TaskStatus))throw Error(`${name}: ${task.TaskStatus}`);
 }
 throw Error(name+': completion unconfirmed');
}
function command(program,args){return new Promise((resolve,reject)=>{
 const child=spawn(program,args,{stdio:['ignore','pipe','pipe']});let error='';
 child.stderr.on('data',data=>{error+=data;});child.on('error',reject);
 child.on('exit',code=>code===0?resolve():reject(Error(program+': '+error)));
});}
const publicKey=(await fs.readFile('.secrets/lighthouse-deploy.pub','utf8')).trim();
try {
 console.log(await run(`set -eu
test "$(hostname)" = VM-0-11-ubuntu
test -d /opt/glb-teaching/build/web/downloads
test "$(df --output=avail -B1 /opt | tail -1)" -gt 500000000
grep -q '${label}' /root/.ssh/authorized_keys || printf '%s\\n' 'no-agent-forwarding,no-port-forwarding,no-X11-forwarding ${publicKey} ${label}' >> /root/.ssh/authorized_keys
echo APK_UPLOAD_READY
`,'glb-scene-apk-access'));
 await command('scp',['-i','.secrets/lighthouse-deploy','-o','UserKnownHostsFile=.secrets/lighthouse-known-hosts','-o','StrictHostKeyChecking=yes','-o','IdentitiesOnly=yes',file,`root@${host}:/root/${name}.upload`]);
 console.log(await run(`set -eu
test "$(hostname)" = VM-0-11-ubuntu
echo '${hash}  /root/${name}.upload' | sha256sum -c -
destination=/opt/glb-teaching/build/web/downloads/${name}
if test -f "$destination"; then echo '${hash}  /opt/glb-teaching/build/web/downloads/${name}' | sha256sum -c -; fi
install -o glbapp -g glbapp -m 644 /root/${name}.upload "$destination"
rm /root/${name}.upload
echo APK_PUBLISHED
`,'glb-scene-apk-publish'));
} finally {
 console.log(await run(`set -eu
test "$(hostname)" = VM-0-11-ubuntu
python3 - <<'PY'
from pathlib import Path
p=Path('/root/.ssh/authorized_keys')
p.write_text('\\n'.join(line for line in p.read_text().splitlines() if '${label}' not in line)+'\\n')
p.chmod(0o600)
print('Temporary APK upload authorization removed.')
PY
`,'glb-scene-apk-cleanup'));
}
const url=`https://${host}/downloads/${name}`;
const response=await fetch(url,{signal:AbortSignal.timeout(300000)});
if(!response.ok)throw Error(`Download HTTP ${response.status}`);
const downloaded=Buffer.from(await response.arrayBuffer());
if(crypto.createHash('sha256').update(downloaded).digest('hex')!==hash)throw Error('Public APK checksum mismatch');
await fs.writeFile('outputs/android-scene/download-verification.json',JSON.stringify({url,sha256:hash,bytes:downloaded.length,checkedAt:new Date().toISOString()},null,2)+'\n');
console.log(JSON.stringify({url,bytes:downloaded.length,sha256:hash,downloadVerified:true}));
