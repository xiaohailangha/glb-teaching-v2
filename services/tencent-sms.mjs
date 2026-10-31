import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {credentials,projectRoot} from './tencent-speech.mjs';

export function smsConfig(){
  const file=path.join(projectRoot,'.secrets/tencent-sms.json');
  const c=fs.existsSync(file)?JSON.parse(fs.readFileSync(file,'utf8').replace(/^\uFEFF/,'')):{};
  return {sdkAppId:process.env.TENCENT_SMS_APP_ID||c.sdkAppId,signName:process.env.TENCENT_SMS_SIGN_NAME||c.signName,templateId:process.env.TENCENT_SMS_TEMPLATE_ID||c.templateId,region:c.region||'ap-guangzhou'};
}
export function smsConfigured(){try{const c=smsConfig(),k=credentials();return !!(c.sdkAppId&&c.signName&&c.templateId&&k.secretId&&k.secretKey);}catch{return false;}}
export async function sendLoginCode(phone,code){
  if(!smsConfigured())throw new Error('SMS_NOT_CONFIGURED');
  const c=smsConfig(),k=credentials(),host='sms.tencentcloudapi.com',service='sms';
  const time=Math.floor(Date.now()/1000),date=new Date(time*1000).toISOString().slice(0,10);
  const body=JSON.stringify({PhoneNumberSet:[phone],SmsSdkAppId:c.sdkAppId,SignName:c.signName,TemplateId:c.templateId,TemplateParamSet:[code]});
  const hash=s=>crypto.createHash('sha256').update(s).digest('hex');
  const hmac=(key,s)=>crypto.createHmac('sha256',key).update(s).digest();
  const scope=`${date}/${service}/tc3_request`;
  const canonical=`POST\n/\n\ncontent-type:application/json; charset=utf-8\nhost:${host}\n\ncontent-type;host\n${hash(body)}`;
  const signing=hmac(hmac(hmac('TC3'+k.secretKey,date),service),'tc3_request');
  const signature=crypto.createHmac('sha256',signing).update(`TC3-HMAC-SHA256\n${time}\n${scope}\n${hash(canonical)}`).digest('hex');
  const r=await fetch('https://'+host,{method:'POST',headers:{'Content-Type':'application/json; charset=utf-8',Authorization:`TC3-HMAC-SHA256 Credential=${k.secretId}/${scope}, SignedHeaders=content-type;host, Signature=${signature}`,'X-TC-Action':'SendSms','X-TC-Version':'2021-01-11','X-TC-Region':c.region,'X-TC-Timestamp':String(time)},body,signal:AbortSignal.timeout(15000)});
  const data=(await r.json()).Response;
  // HTTP 200 alone is not successful delivery acceptance. Never leak raw provider data.
  if(!r.ok||data?.Error||data?.SendStatusSet?.[0]?.Code!=='Ok')throw new Error('SMS_SEND_FAILED');
}
