import crypto from 'node:crypto';
import {credentials} from './tencent-speech.mjs';
export async function billingApi(action,payload){
 const c=credentials();if(!c.secretId||!c.secretKey)throw Error('腾讯云凭据未配置');
 const service='billing',host='billing.tencentcloudapi.com',time=Math.floor(Date.now()/1000),date=new Date(time*1000).toISOString().slice(0,10),body=JSON.stringify(payload);
 const sha=s=>crypto.createHash('sha256').update(s).digest('hex'),hmac=(k,s)=>crypto.createHmac('sha256',k).update(s).digest();
 const scope=`${date}/${service}/tc3_request`,canonical=`POST\n/\n\ncontent-type:application/json; charset=utf-8\nhost:${host}\n\ncontent-type;host\n${sha(body)}`;
 const key=hmac(hmac(hmac('TC3'+c.secretKey,date),service),'tc3_request');
 const signature=crypto.createHmac('sha256',key).update(`TC3-HMAC-SHA256\n${time}\n${scope}\n${sha(canonical)}`).digest('hex');
 const response=await fetch('https://'+host,{method:'POST',headers:{'Content-Type':'application/json; charset=utf-8',Authorization:`TC3-HMAC-SHA256 Credential=${c.secretId}/${scope}, SignedHeaders=content-type;host, Signature=${signature}`,'X-TC-Action':action,'X-TC-Version':'2018-07-09','X-TC-Timestamp':String(time)},body,signal:AbortSignal.timeout(25000)});
 const data=(await response.json()).Response;
 if(!response.ok||!data||data.Error)throw Error(data?.Error?.Code?.startsWith('Unauthorized')?'账单读取权限不足，请配置费用中心只读权限':`腾讯账单暂不可用${data?.Error?.Code?'（'+data.Error.Code+'）':''}`);
 return data;
}
export async function fetchBill(month,api=billingApi){
 const summary=await api('DescribeBillSummaryByProduct',{BeginTime:month,EndTime:month});
 if(summary.Ready===0)throw Error('腾讯账单尚未准备完成，请稍后同步');
 const details=[];let offset=0,context;
 while(true){
 const data=await api('DescribeBillDetail',{Month:month,Offset:offset,Limit:100,NeedRecordNum:1,...(context?{Context:context}:{})});
 const rows=data.DetailSet||[];details.push(...rows);if(rows.length<100)break;
 context=data.Context;offset+=rows.length;if(offset>=100000)throw Error('明细过多，请使用腾讯账单导出');
 await new Promise(r=>setTimeout(r,220));
 }
 return {summary,details,source:'腾讯云官方账单',scope:'腾讯云账号全产品账单；可能含其他项目',month};
}
