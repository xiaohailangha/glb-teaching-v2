import crypto from 'node:crypto';
import {credentials,validateAudio} from './tencent-speech.mjs';
const hash=s=>crypto.createHash('sha256').update(s).digest('hex');
const hmac=(key,s)=>crypto.createHmac('sha256',key).update(s).digest();
// Completed utterances use the short-recording API, not a real-time re-stream.
export async function recognizeRecording(wav,{signal}={}){
 validateAudio(wav);const c=credentials(),service='asr',host='asr.tencentcloudapi.com';
 const time=Math.floor(Date.now()/1000),date=new Date(time*1000).toISOString().slice(0,10);
 const body=JSON.stringify({EngSerViceType:'16k_en',SourceType:1,VoiceFormat:'wav',Data:wav.toString('base64'),DataLen:wav.length,UsrAudioKey:crypto.randomUUID()});
 const canonical=`POST\n/\n\ncontent-type:application/json; charset=utf-8\nhost:${host}\n\ncontent-type;host\n${hash(body)}`;
 const scope=`${date}/${service}/tc3_request`,key=hmac(hmac(hmac('TC3'+c.secretKey,date),service),'tc3_request');
 const signature=crypto.createHmac('sha256',key).update(`TC3-HMAC-SHA256\n${time}\n${scope}\n${hash(canonical)}`).digest('hex');
 const r=await fetch('https://'+host,{method:'POST',headers:{'Content-Type':'application/json; charset=utf-8',Authorization:`TC3-HMAC-SHA256 Credential=${c.secretId}/${scope}, SignedHeaders=content-type;host, Signature=${signature}`,'X-TC-Action':'SentenceRecognition','X-TC-Version':'2019-06-14','X-TC-Region':'ap-beijing','X-TC-Timestamp':String(time)},body,signal:signal||AbortSignal.timeout(12000)});
 const result=(await r.json()).Response;if(!r.ok||result?.Error)throw Error(result?.Error?.Code||'ASRUnavailable');
 return {text:result.Result||'',engine:'SentenceRecognition/16k_en',requestId:result.RequestId};
}
