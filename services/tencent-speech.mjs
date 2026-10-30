import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';

export const projectRoot=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
export const cacheDir=path.join(projectRoot,'work/tencent-cache');
export const versions={tts:'超自然大模型 2.0 / stream_wsv2',asr:'实时识别 V2 / 16k_zh_en_2.0',assessment:'智聆口语评测（新版） / soe/api'};
export function credentials(){
  let c={};const file=path.join(projectRoot,'.secrets/tencent.json');
  if(fs.existsSync(file)){try{c=JSON.parse(fs.readFileSync(file,'utf8').replace(/^\uFEFF/,''));}catch{throw new Error('本地腾讯凭据文件格式无效');}}
  return {appId:process.env.TENCENT_APP_ID||c.appId,secretId:process.env.TENCENT_SECRET_ID||c.secretId,secretKey:process.env.TENCENT_SECRET_KEY||c.secretKey};
}
export function configured(){try{const c=credentials();return !!(c.appId&&c.secretId&&c.secretKey);}catch{return false;}}
export function signedUrl(hostPath,params,key,{tts=false}={}){
  const keys=Object.keys(params).sort();
  const raw=keys.map(k=>`${k}=${params[k]}`).join('&');
  const signature=crypto.createHmac('sha1',key).update(`${tts?'GET':''}${hostPath}?${raw}`).digest('base64');
  return `wss://${hostPath}?${keys.map(k=>`${encodeURIComponent(k)}=${encodeURIComponent(params[k])}`).join('&')}&${tts?'Signature':'signature'}=${encodeURIComponent(signature)}`;
}
function auth(){const c=credentials();if(!c.appId||!c.secretId||!c.secretKey)throw new Error('腾讯云凭据尚未配置');return c;}
const nonce=()=>crypto.randomInt(1,2147483647);
export function pcmWave(pcm,rate=16000){
  const h=Buffer.alloc(44);h.write('RIFF');h.writeUInt32LE(pcm.length+36,4);h.write('WAVEfmt ',8);h.writeUInt32LE(16,16);h.writeUInt16LE(1,20);h.writeUInt16LE(1,22);h.writeUInt32LE(rate,24);h.writeUInt32LE(rate*2,28);h.writeUInt16LE(2,32);h.writeUInt16LE(16,34);h.write('data',36);h.writeUInt32LE(pcm.length,40);return Buffer.concat([h,pcm]);
}
export function readWave(wav){
  if(wav.length<44||wav.toString('ascii',0,4)!=='RIFF'||wav.toString('ascii',8,12)!=='WAVE')throw new Error('需要 PCM WAV 音频');
  let format,pcm;
  for(let at=12;at+8<=wav.length;){
    const id=wav.toString('ascii',at,at+4),n=wav.readUInt32LE(at+4),start=at+8;
    if(start+n>wav.length)throw new Error('音频文件不完整');
    if(id==='fmt '&&n>=16)format={codec:wav.readUInt16LE(start),channels:wav.readUInt16LE(start+2),rate:wav.readUInt32LE(start+4),bits:wav.readUInt16LE(start+14)};
    if(id==='data')pcm=wav.subarray(start,start+n);
    at=start+n+(n%2);
  }
  if(!format||format.codec!==1||format.channels!==1||format.rate!==16000||format.bits!==16||!pcm||pcm.length%2)throw new Error('音频必须为 16kHz 单声道 PCM16');
  return {pcm,duration:pcm.length/32000};
}
export function validateAudio(wav,{maxSeconds=20,minSeconds=.25}={}){
  const parsed=readWave(wav);if(parsed.duration<minSeconds||parsed.duration>maxSeconds)throw new Error(`请录制 ${minSeconds} 至 ${maxSeconds} 秒音频`);
  let sum=0;for(let i=0;i<parsed.pcm.length;i+=2){const x=parsed.pcm.readInt16LE(i)/32768;sum+=x*x;}
  if(Math.sqrt(sum/(parsed.pcm.length/2))<.001)throw new Error('没有听到清晰声音，请靠近麦克风重试');
  return parsed;
}
export function speechText(value,max=300){
  if(typeof value!=='string'||!value.trim()||value.length>max||/[<>\x00-\x08]/.test(value))throw new Error('教学文本为空、过长或包含不支持的标记');return value.trim();
}
// Never return signed URLs or raw network errors containing credentials.
function exchange(url,{signal,timeout=45000,onMessage,onBinary}){
  return new Promise((resolve,reject)=>{
    const ws=new WebSocket(url);ws.binaryType='arraybuffer';let done=false;
    const finish=(error,result)=>{if(done)return;done=true;clearTimeout(timer);signal?.removeEventListener('abort',abort);try{ws.close();}catch{}error?reject(error):resolve(result);};
    const abort=()=>finish(new Error('操作已取消'));
    const timer=setTimeout(()=>finish(new Error('腾讯语音服务响应超时，请重试')),timeout);
    if(signal?.aborted){abort();return;}signal?.addEventListener('abort',abort,{once:true});
    ws.onerror=()=>finish(new Error('腾讯语音连接失败，请检查网络和服务权限'));
    ws.onclose=()=>{if(!done)finish(new Error('腾讯语音连接提前结束'));};
    ws.onmessage=event=>{
      if(done)return;
      try{
        if(typeof event.data!=='string'){onBinary?.(Buffer.from(event.data));return;}
        const msg=JSON.parse(event.data);
        if(msg.code!==undefined&&msg.code!==0){finish(new Error(`腾讯语音错误 ${msg.code}：${String(msg.message||'调用失败').replace(/AKID\w+/g,'[redacted]').slice(0,240)}`));return;}
        onMessage(msg,ws,finish);
      }catch{finish(new Error('腾讯语音返回数据格式异常'));}
    };
  });
}
export async function synthesize(text,{voice=403007,speed=0,signal}={}){
  text=speechText(text);if(![403006,403007,403008,403004].includes(voice))throw new Error('不支持的教学音色');
  if(!Number.isFinite(speed)||speed< -2||speed>2)throw new Error('不支持的语速');
  const c=auth(),now=Math.floor(Date.now()/1000),session=crypto.randomUUID();
  const params={Action:'TextToStreamAudioWSv2',AppId:c.appId,SecretId:c.secretId,Timestamp:now,Expired:now+300,SessionId:session,VoiceType:voice,SampleRate:16000,Codec:'pcm',EnableSubtitle:'True',Speed:speed};
  const chunks=[],subtitles=[];let sent=false,bytes=0;
  return exchange(signedUrl('tts.cloud.tencent.com/stream_wsv2',params,c.secretKey,{tts:true}),{signal,
    onBinary:b=>{bytes+=b.length;if(bytes>32000*60)throw new Error('音频过长');chunks.push(b);},
    onMessage:(m,ws,finish)=>{
      if(m.result?.subtitles)subtitles.push(...m.result.subtitles);
      if(m.ready===1&&!sent){sent=true;for(const [action,data]of [['ACTION_SYNTHESIS',text],['ACTION_COMPLETE','']])ws.send(JSON.stringify({session_id:session,message_id:crypto.randomUUID(),action,data}));}
      if(m.final===1){const pcm=Buffer.concat(chunks);if(!pcm.length)return finish(new Error('合成未返回音频'));finish(null,{wav:pcmWave(pcm),subtitles,duration:pcm.length/32000,voice,text});}
    }});
}
export async function assess(wav,{text,language='en',strictness=2,signal}={}){
  text=speechText(text);const {duration}=validateAudio(wav,{maxSeconds:60});
  if(!['en','zh'].includes(language)||!Number.isFinite(strictness)||strictness<1||strictness>4)throw new Error('评测参数无效');
  const wordCount=language==='zh'?text.replace(/[^\p{Script=Han}]/gu,'').length:text.split(/\s+/).length;
  if(wordCount>120)throw new Error('单次评测文本过长');
  const c=auth(),now=Math.floor(Date.now()/1000);
  const params={secretid:c.secretId,timestamp:now,expired:now+300,nonce:nonce(),server_engine_type:`16k_${language}`,voice_id:crypto.randomUUID(),voice_format:1,text_mode:0,ref_text:text,eval_mode:wordCount===1?0:wordCount<=30?1:2,score_coeff:strictness,rec_mode:1,sentence_info_enabled:1};
  let sent=false,lastResult=null;
  return exchange(signedUrl(`soe.cloud.tencent.com/soe/api/${c.appId}`,params,c.secretKey),{signal,timeout:Math.max(45000,duration*1500),onMessage:(m,ws,finish)=>{
    if(m.result){const result=typeof m.result==='string'?JSON.parse(m.result):m.result;if(result.Words)lastResult=result;}
    if(!sent){sent=true;ws.send(wav);ws.send(JSON.stringify({type:'end'}));}
    if(m.final===1)lastResult?finish(null,lastResult):finish(new Error('评测未返回有效结果'));
  }});
}
export async function recognize(wav,{signal,onEvent}={}){
  const {pcm,duration}=validateAudio(wav),c=auth(),now=Math.floor(Date.now()/1000);
  const params={secretid:c.secretId,timestamp:now,expired:now+300,nonce:nonce(),engine_model_type:'16k_zh_en_2.0',voice_id:crypto.randomUUID(),voice_format:1,filter_dirty:0,filter_modal:0,filter_punc:0,filter_empty_result:0,convert_num_mode:0};
  let sent=false,timer;const sentences=new Map();
  try{return await exchange(signedUrl(`asr.cloud.tencent.com/asr/v2/${c.appId}`,params,c.secretKey),{signal,timeout:duration*1000+25000,onMessage:(m,ws,finish)=>{
    onEvent?.(m);
    if(m.sentences){const rows=Array.isArray(m.sentences)?m.sentences:[m.sentences];for(const row of rows)if(typeof row.sentence==='string')sentences.set(row.sentence_id??0,row.sentence);}
    // Non-diarized 2.0 currently returns result.voice_text_str, unlike the V2 documentation's speaker schema.
    if(typeof m.result?.voice_text_str==='string')sentences.set(m.result.index??0,m.result.voice_text_str);
    if(!sent){sent=true;let at=0;const send=()=>{if(ws.readyState!==WebSocket.OPEN)return;if(at>=pcm.length){ws.send(JSON.stringify({type:'end'}));return;}ws.send(pcm.subarray(at,at+6400));at+=6400;timer=setTimeout(send,200);};send();}
    if(m.final===1)finish(null,{text:[...sentences.entries()].sort((a,b)=>a[0]-b[0]).map(([,v])=>v).join(' '),engine:params.engine_model_type});
  }});}finally{clearTimeout(timer);}
}

const enViseme={aa:2,ae:1,ah:1,ao:3,aw:9,ay:11,eh:4,er:5,ey:4,ih:6,iy:6,ow:8,oy:10,uh:4,uw:7,ax:1,b:21,p:21,m:21,f:18,v:18,th:17,dh:17,t:19,d:19,n:19,l:14,r:13,s:15,z:15,sh:16,zh:16,ch:16,jh:16,k:20,g:20,ng:20,h:12,hh:12,w:7,y:6,sil:0,sp:0};
export function phoneViseme(phone,language='en'){
  const p=String(phone).toLowerCase().replace(/[0-9#]/g,'');
  if(language==='en')return enViseme[p]??null;
  const initials={b:21,p:21,m:21,f:18,d:19,t:19,n:19,l:14,g:20,k:20,h:12,j:16,q:16,x:16,zh:16,ch:16,sh:16,r:13,z:15,c:15,s:15,w:7,y:6};
  if(p in initials)return initials[p];if(p==='sil'||p==='sp')return 0;
  if(/^(u|v|ü)/.test(p))return 7;if(/^o/.test(p))return 8;if(/^i/.test(p))return 6;if(/^e/.test(p))return 4;if(/^a/.test(p))return 2;return null;
}
export function alignmentCues(result,duration,language='en'){
  const phones=[];let missing=0;
  for(const w of result.Words||[])for(const p of w.PhoneInfos||[]){
    const start=Number(p.MemBeginTime)/1000,end=Number(p.MemEndTime)/1000,id=phoneViseme(p.Phone,language);
    if(!Number.isFinite(start)||!Number.isFinite(end)||end<=start||start<0||end>duration+.15||id===null){missing++;continue;}
    if(start>=duration){missing++;continue;}
    phones.push({start,end:Math.min(end,duration),id,phone:p.Phone});
  }
  phones.sort((a,b)=>a.start-b.start);const cues=[{time:0,id:0}];let end=0;
  for(const p of phones){if(p.start<end-.03){missing++;continue;}if(p.start>end+.025)cues.push({time:end,id:0});cues.push({time:p.start,id:p.id});end=p.end;}
  cues.push({time:Math.min(duration,end),id:0});
  return {cues: cues.sort((a,b)=>a.time-b.time).filter((c,i,a)=>i===a.length-1||c.time!==a[i+1].time),phones,missing,usable:phones.length>0&&missing===0,source:'tencent-soe-new-phone-timing'};
}
const pending=new Map();
export async function teachingAudio(text,{voice=403007,speed=0,language='en'}={}){
  if(!['en','zh'].includes(language))throw new Error('不支持的教学语言');
  text=speechText(text);const key=crypto.createHash('sha256').update(JSON.stringify({version:1,text,voice,speed,language})).digest('hex');
  fs.mkdirSync(cacheDir,{recursive:true});const jsonFile=path.join(cacheDir,`${key}.json`),wavFile=path.join(cacheDir,`${key}.wav`);
  if(fs.existsSync(jsonFile)&&fs.existsSync(wavFile))return {...JSON.parse(fs.readFileSync(jsonFile,'utf8')),cached:true};
  if(pending.has(key))return pending.get(key);
  const job=(async()=>{
    // Save synthesis separately so an alignment retry never pays for TTS again.
    const rawFile=path.join(cacheDir,`${key}.raw.json`);let generated;
    if(fs.existsSync(rawFile)&&fs.existsSync(wavFile))generated={...JSON.parse(fs.readFileSync(rawFile,'utf8')),wav:fs.readFileSync(wavFile)};
    else{generated=await synthesize(text,{voice,speed});fs.writeFileSync(wavFile,generated.wav);const {wav,...metadata}=generated;fs.writeFileSync(rawFile,JSON.stringify(metadata));}
    // Keep the cloud alignment response for local mapping fixes without charging again.
    const alignmentFile=path.join(cacheDir,`${key}.alignment.json`);
    let result;
    if(fs.existsSync(alignmentFile))result=JSON.parse(fs.readFileSync(alignmentFile,'utf8'));
    else{result=await assess(generated.wav,{text,language,strictness:2});fs.writeFileSync(alignmentFile,JSON.stringify(result,null,2));}
    const alignment=alignmentCues(result,generated.duration,language);
    if(!alignment.usable)throw new Error('音素时间数据不完整，已保留音频等待校准；不会用随机口型替代');
    const item={key,text,voice,speed,language,duration:generated.duration,subtitles:generated.subtitles,...alignment,audioUrl:`/api/speech/audio/${key}.wav`,versions,cached:false};
    fs.writeFileSync(jsonFile,JSON.stringify(item,null,2));return item;
  })();pending.set(key,job);try{return await job;}finally{pending.delete(key);}
}
