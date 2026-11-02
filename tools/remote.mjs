import fs from 'node:fs/promises';
import {spawn} from 'node:child_process';
import {api} from './tencent-deploy-api.mjs';
export const host='49.233.179.83';
export async function remote(source,name='snow-project-deploy'){
 const request=await api('tat','RunCommand',{InstanceIds:['lhins-52h0i09a'],CommandName:name,CommandType:'SHELL',Content:Buffer.from(source).toString('base64'),SaveCommand:false,Timeout:180,Username:'root'});
 for(let i=0;i<95;i++){
  await new Promise(r=>setTimeout(r,2000));
  const data=await api('tat','DescribeInvocationTasks',{Filters:[{Name:'invocation-id',Values:[request.InvocationId]}],HideOutput:false});
  const task=data.InvocationTaskSet?.[0];if(!task)continue;
  const output=Buffer.from(task.TaskResult?.Output||'','base64').toString();
  if(task.TaskStatus==='SUCCESS')return output;
  if(['FAILED','TIMEOUT','CANCELLED'].includes(task.TaskStatus))throw Error(name+': '+task.TaskStatus+'\n'+output);
 }
 throw Error('Remote completion unconfirmed');
}
export function command(program,args){return new Promise((resolve,reject)=>{
 const child=spawn(program,args,{stdio:['ignore','pipe','pipe']});let output='';child.stdout.on('data',b=>output+=b);child.stderr.on('data',b=>output+=b);child.on('error',reject);child.on('exit',code=>code===0?resolve(output):reject(Error(program+': '+output)));
});}
export async function upload(files){
 const key=(await fs.readFile('.secrets/lighthouse-deploy.pub','utf8')).trim(),label='snow-project-upload-'+Date.now();
 const keyParts=key.split(/\s+/).slice(0,2).join(' ');
 try{
  await remote(`set -eu\ninstall -d -m 700 /root/.ssh\ntouch /root/.ssh/authorized_keys\nprintf '%s\\n' 'no-agent-forwarding,no-port-forwarding,no-X11-forwarding ${keyParts} ${label}' >> /root/.ssh/authorized_keys\nchmod 600 /root/.ssh/authorized_keys`);
  for(const [source,target]of files)await command('scp',['-i','.secrets/lighthouse-deploy','-o','BatchMode=yes','-o','ConnectTimeout=15','-o','UserKnownHostsFile=.secrets/lighthouse-known-hosts','-o','StrictHostKeyChecking=yes','-o','IdentitiesOnly=yes',source,`root@${host}:${target}`]);
 }finally{
  await remote(`set -eu\nsed -i '/${label}/d' /root/.ssh/authorized_keys`,'snow-project-upload-cleanup');
 }
}
