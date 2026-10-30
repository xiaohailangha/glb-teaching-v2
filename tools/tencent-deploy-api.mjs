// Narrow deployment helper. Credentials are read locally and never printed.
import fs from 'node:fs';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
const root=fileURLToPath(new URL('../',import.meta.url));
const instance='lhins-52h0i09a';
const hash=s=>crypto.createHash('sha256').update(s).digest('hex');
const hmac=(key,s)=>crypto.createHmac('sha256',key).update(s).digest();
export async function api(service,action,payload){
 const c=JSON.parse(fs.readFileSync(root+'.secrets/tencent.json','utf8').replace(/^\uFEFF/,''));
 const host=service+'.tencentcloudapi.com',time=Math.floor(Date.now()/1000),date=new Date(time*1000).toISOString().slice(0,10);
 const body=JSON.stringify(payload),scope=`${date}/${service}/tc3_request`;
 const canonical=`POST\n/\n\ncontent-type:application/json; charset=utf-8\nhost:${host}\n\ncontent-type;host\n${hash(body)}`;
 const sign=hmac(hmac(hmac('TC3'+c.secretKey,date),service),'tc3_request');
 const signature=crypto.createHmac('sha256',sign).update(`TC3-HMAC-SHA256\n${time}\n${scope}\n${hash(canonical)}`).digest('hex');
 const r=await fetch('https://'+host,{method:'POST',headers:{'Content-Type':'application/json; charset=utf-8',Authorization:`TC3-HMAC-SHA256 Credential=${c.secretId}/${scope}, SignedHeaders=content-type;host, Signature=${signature}`,'X-TC-Action':action,'X-TC-Version':service==='tat'?'2020-10-28':'2020-03-24','X-TC-Region':'ap-beijing','X-TC-Timestamp':String(time)},body,signal:AbortSignal.timeout(25000)});
 const result=(await r.json()).Response;if(result.Error)throw Error(result.Error.Code+': '+result.Error.Message);return result;
}
if(process.argv[1]===fileURLToPath(import.meta.url)){
 const [mode,arg]=process.argv.slice(2);
 if(mode==='inspect'){
   const r=await api('lighthouse','DescribeInstances',{InstanceIds:[instance]});
   console.log(JSON.stringify(r));
   console.log(JSON.stringify(await api('lighthouse','DescribeFirewallRules',{InstanceId:instance})));
 }else if(mode==='run'){
   const content=fs.readFileSync(arg);
   const r=await api('tat','RunCommand',{InstanceIds:[instance],CommandName:'glb-teaching-deploy',CommandType:'SHELL',Content:content.toString('base64'),SaveCommand:false,Timeout:1800,Username:'root'});
   console.log(JSON.stringify(r));
 }else if(mode==='poll'){
   const r=await api('tat','DescribeInvocationTasks',{Filters:[{Name:'invocation-id',Values:[arg]}],HideOutput:false});
   for(const t of r.InvocationTaskSet||[])console.log(JSON.stringify({status:t.TaskStatus,result:{...t.TaskResult,Output:t.TaskResult?.Output?Buffer.from(t.TaskResult.Output,'base64').toString():''}}));
 }else throw Error('Use inspect, run FILE, poll INVOCATION');
}
