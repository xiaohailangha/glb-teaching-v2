import {liveRecognitionHandler} from './live-recognition.mjs';
const liveRecognition=liveRecognitionHandler();
import fs from 'node:fs';
import path from 'node:path';
import {configured,versions,cacheDir,teachingAudio,assess,recognize,validateAudio,speechText} from './tencent-speech.mjs';

let inFlight=0;
const hits=new Map();
export function trustedRequest(req){
  if(!['127.0.0.1','::1','::ffff:127.0.0.1'].includes(req.socket.remoteAddress))return false;
  const host=req.headers.host||'';
  if(!/^(localhost|127\.0\.0\.1|\[::1\])(:\d+)?$/.test(host))return false;
  if(req.headers.origin&&req.headers.origin!==`http://${host}`)return false;
  return !req.headers['sec-fetch-site']||['same-origin','none'].includes(req.headers['sec-fetch-site']);
}
export async function readBody(req,limit){
  const chunks=[];let size=0;
  for await(const chunk of req){size+=chunk.length;if(size>limit)throw new Error('请求内容过大');chunks.push(chunk);}return Buffer.concat(chunks);
}
function reply(res,status,value){res.writeHead(status,{'Content-Type':'application/json; charset=utf-8','Cache-Control':'no-store'}).end(JSON.stringify(value));}
export async function speechHttp(req,res,url){
  if(!url.pathname.startsWith('/api/speech/'))return false;
  if(!trustedRequest(req)){reply(res,403,{error:'仅允许本机项目页面访问'});return true;}
  if(req.method==='GET'&&url.pathname==='/api/speech/status'){reply(res,200,{configured:configured(),versions,voices:[{id:403007,name:'YunLeo · 美音男声'},{id:403006,name:'YunMia · 美音女声'},{id:403008,name:'云小洋 · 男童'},{id:403004,name:'云大川 · 男老师'}]});return true;}
  if(req.method==='GET'&&/^\/api\/speech\/audio\/[a-f0-9]{64}\.wav$/.test(url.pathname)){
    const file=path.join(cacheDir,path.basename(url.pathname));if(!fs.existsSync(file)){reply(res,404,{error:'音频不存在'});return true;}
    res.writeHead(200,{'Content-Type':'audio/wav','Cache-Control':'private, max-age=86400','Content-Length':fs.statSync(file).size});fs.createReadStream(file).pipe(res);return true;
  }
  if(req.method!=='POST'||!['/api/speech/tts','/api/speech/assess','/api/speech/recognize'].includes(url.pathname)){reply(res,404,{error:'接口不存在'});return true;}
  if(url.pathname==='/api/speech/recognize'&&url.searchParams.has('live')){
    if(!configured()){reply(res,503,{error:'语音尚未配置'});return true;}
    return liveRecognition(req,res,url);
  }
  const now=Date.now(),key=req.socket.remoteAddress,recent=(hits.get(key)||[]).filter(t=>now-t<60000);
  if(inFlight>=2||recent.length>=30){reply(res,429,{error:'请求较多，请稍后重试'});return true;}recent.push(now);hits.set(key,recent);inFlight++;
  const abort=new AbortController();res.on('close',()=>{if(!res.writableEnded)abort.abort();});
  try{
    if(!configured()){reply(res,503,{error:'腾讯云凭据尚未配置'});return true;}
    if(url.pathname==='/api/speech/tts'){
      if(!req.headers['content-type']?.startsWith('application/json'))throw new Error('需要 JSON 请求');
      const input=JSON.parse((await readBody(req,5000)).toString('utf8'));
      const item=await teachingAudio(input.text,{voice:input.voice??403007,speed:input.speed??0,language:input.language??'en'});reply(res,200,item);
    }else{
      if(req.headers['content-type']!=='audio/wav')throw new Error('需要 WAV 音频');
      const wav=await readBody(req,640044);validateAudio(wav);
      if(url.pathname.endsWith('/recognize'))reply(res,200,await recognize(wav,{signal:abort.signal}));
      else{
        const text=speechText(url.searchParams.get('text'),180);
        if(!/^[a-zA-Z][a-zA-Z\s.,!?'-]*$/.test(text)||text.split(/\s+/).length>30)throw new Error('跟读仅支持英文单词或短句，不评测孤立音标');
        const result=await assess(wav,{text,language:'en',strictness:2,signal:abort.signal});reply(res,200,{result,reference:text,engine:'soe-new',strictness:2});
      }
    }
  }catch(error){if(!res.destroyed)reply(res,400,{error:error.message||'语音服务暂时不可用'});}finally{inFlight--;}
  return true;
}
