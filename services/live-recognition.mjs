import crypto from 'node:crypto';
import {credentials,signedUrl} from './tencent-speech.mjs';

// One short-lived upstream per spoken turn; keys and signed URLs never leave here.
export function openRecognizer(){
 const c=credentials(),now=Math.floor(Date.now()/1000);
 const params={secretid:c.secretId,timestamp:now,expired:now+120,nonce:crypto.randomInt(1,2147483647),engine_model_type:'16k_zh_en_2.0',voice_id:crypto.randomUUID(),voice_format:1,filter_empty_result:0};
 const ws=new WebSocket(signedUrl(`asr.cloud.tencent.com/asr/v2/${c.appId}`,params,c.secretKey));
 const sentences=new Map();let error='',done=false,ready=false;
 let resolveReady,resolveDone;
 const connected=new Promise(r=>resolveReady=r),finished=new Promise(r=>resolveDone=r);
 const close=()=>{done=true;resolveReady();resolveDone();try{ws.close();}catch{}};
 ws.onerror=()=>{error='实时识别连接失败';close();};
 ws.onclose=()=>{if(!done){error='实时识别连接中断';close();}};
 ws.onmessage=e=>{try{const m=JSON.parse(e.data);if(m.code){error='实时识别暂不可用';close();return;}
   if(!ready){ready=true;resolveReady();}
   if(typeof m.result?.voice_text_str==='string')sentences.set(m.result.index??0,m.result.voice_text_str);
   if(m.sentences)for(const row of (Array.isArray(m.sentences)?m.sentences:[m.sentences]))if(typeof row.sentence==='string')sentences.set(row.sentence_id??0,row.sentence);
   if(m.final===1)close();
 }catch{error='实时识别返回异常';close();}};
 const snapshot=()=>({text:[...sentences.entries()].sort((a,b)=>a[0]-b[0]).map(x=>x[1]).join(' '),...(error?{error}:{})});
 return {snapshot,close,async send(bytes){await connected;if(error||done)throw Error(error||'识别已结束');ws.send(bytes);},async end(){await connected;if(!done)ws.send(JSON.stringify({type:'end'}));await finished;return snapshot();}};
}

export function liveRecognitionHandler({factory=openRecognizer,clock=Date.now}={}){
 const sessions=new Map(),starts=[];
 const respond=(res,code,value)=>res.writeHead(code,{'Content-Type':'application/json','Cache-Control':'no-store'}).end(JSON.stringify(value));
 const remove=id=>{const s=sessions.get(id);if(s){clearTimeout(s.timer);s.upstream.close();sessions.delete(id);}};
 return async(req,res,url)=>{
  const action=url.searchParams.get('live');if(!action)return false;
  const id=url.searchParams.get('id');
  try{
   if(req.method!=='POST')throw Error('需要 POST');
   if(action==='start'){
    while(starts.length&&clock()-starts[0]>60000)starts.shift();
    if(sessions.size>=2||starts.length>=24){respond(res,429,{error:'请稍后重试'});return true;}
    starts.push(clock());const key=crypto.randomBytes(24).toString('hex');
    const session={upstream:factory(),bytes:0,busy:false,timer:setTimeout(()=>remove(key),22000)};
    sessions.set(key,session);respond(res,200,{id:key});return true;
   }
   if(!/^[a-f0-9]{48}$/.test(id||''))throw Error('识别会话无效');
   const s=sessions.get(id);if(!s)throw Error('识别会话已结束');
   if(action==='cancel'){remove(id);respond(res,200,{});return true;}
   if(s.busy)throw Error('音频顺序错误');s.busy=true;
   if(action==='chunk'){
    if(req.headers['content-type']!=='application/octet-stream')throw Error('需要 PCM');
    const chunks=[];let size=0;for await(const b of req){size+=b.length;if(size>32000)throw Error('音频片段过大');chunks.push(b);}
    s.bytes+=size;if(size%2||s.bytes>640000)throw Error('录音超出范围');
    await s.upstream.send(Buffer.concat(chunks));s.busy=false;respond(res,200,s.upstream.snapshot());
   }else if(action==='end'){const result=await s.upstream.end();remove(id);respond(res,200,result);}
   else throw Error('识别操作无效');
  }catch{if(id)remove(id);if(!res.destroyed)respond(res,400,{error:'实时文字暂不可用，发音评测仍可继续'});}
  return true;
 };
}
