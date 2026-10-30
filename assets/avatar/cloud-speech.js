// Audio and phoneme timings always travel as one versioned asset.
export class CloudSpeech {
  constructor(){this.status=null;this.cache=new Map();}
  async init(){try{const r=await fetch('/api/speech/status');if(r.ok)this.status=await r.json();}catch{}return this.status;}
  get enabled(){return this.status?.configured===true;}
  async prepare(text,{language='en',voice=403007,speed=0}={}){
    if(!this.enabled)throw new Error('腾讯语音服务尚未连接');
    const key=JSON.stringify({text,language,voice,speed});if(this.cache.has(key))return this.cache.get(key);
    const response=await fetch('/api/speech/tts',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({text,language,voice,speed})});
    const data=await response.json();if(!response.ok)throw new Error(data.error||'腾讯语音生成失败');
    if(!data.usable||!data.cues?.length)throw new Error('口型时间数据不完整');this.cache.set(key,data);return data;
  }
}

export function wavFromFloat(samples,sourceRate){
  const length=Math.floor(samples.length*16000/sourceRate),buffer=new ArrayBuffer(44+length*2),v=new DataView(buffer);
  const write=(at,s)=>{for(let i=0;i<s.length;i++)v.setUint8(at+i,s.charCodeAt(i));};
  write(0,'RIFF');v.setUint32(4,36+length*2,true);write(8,'WAVEfmt ');v.setUint32(16,16,true);v.setUint16(20,1,true);v.setUint16(22,1,true);v.setUint32(24,16000,true);v.setUint32(28,32000,true);v.setUint16(32,2,true);v.setUint16(34,16,true);write(36,'data');v.setUint32(40,length*2,true);
  // Average each source window before decimation; no assumptions about device sample rate.
  for(let i=0;i<length;i++){const a=i*sourceRate/16000,b=(i+1)*sourceRate/16000;let sum=0,weight=0;for(let j=Math.floor(a);j<Math.ceil(b)&&j<samples.length;j++){const w=Math.min(b,j+1)-Math.max(a,j);sum+=samples[j]*w;weight+=w;}const x=Math.max(-1,Math.min(1,sum/(weight||1)));v.setInt16(44+i*2,Math.round(x*(x<0?32768:32767)),true);}return buffer;
}
export class LearnerRecorder {
  constructor(emit){this.emit=emit;this.current=null;}
  async start({mode='assess',text,session}){
    this.cancel();const token={mode,text,session,chunks:[],length:0};this.current=token;
    try{
      const stream=await navigator.mediaDevices.getUserMedia({audio:{channelCount:1,echoCancellation:true,noiseSuppression:true},video:false});
      if(this.current!==token){stream.getTracks().forEach(t=>t.stop());return;}
      token.stream=stream;token.ctx=new AudioContext();await token.ctx.resume();
      await token.ctx.audioWorklet.addModule(new URL('./microphone-worklet.js',import.meta.url));
      if(this.current!==token){this.cleanup(token);return;}
      token.source=token.ctx.createMediaStreamSource(stream);token.node=new AudioWorkletNode(token.ctx,'lesson-microphone');
      token.node.port.onmessage=({data})=>{if(this.current!==token)return;if(data.flushed){token.onFlushed?.();return;}token.chunks.push(data);token.length+=data.length;};
      const mute=token.ctx.createGain();mute.gain.value=0;token.source.connect(token.node);token.node.connect(mute);mute.connect(token.ctx.destination);
      this.emit('capture',{session,state:'recording',mode});token.timer=setTimeout(()=>this.finish(),15000);
    }catch(error){this.cleanup(token);if(this.current===token){this.current=null;this.emit('capture',{session,state:'error',message:error.name==='NotAllowedError'?'麦克风未获允许，请在浏览器中允许后再试':error.message});}}
  }
  cleanup(t){if(!t)return;clearTimeout(t.timer);t.source?.disconnect();t.node?.disconnect();t.stream?.getTracks().forEach(s=>s.stop());t.ctx?.close().catch(()=>{});}
  cancel(){const t=this.current;this.current=null;if(t){t.abort?.abort();this.cleanup(t);}}
  async finish(){
    const t=this.current;if(!t||t.finishing||!t.ctx)return;t.finishing=true;const rate=t.ctx.sampleRate;
    await new Promise(resolve=>{const timeout=setTimeout(resolve,250);t.onFlushed=()=>{clearTimeout(timeout);resolve();};t.node?.port.postMessage('flush');});
    if(this.current!==t)return;
    const samples=new Float32Array(t.length);let at=0;for(const chunk of t.chunks){samples.set(chunk,at);at+=chunk.length;}this.cleanup(t);
    this.emit('capture',{session:t.session,state:'processing',mode:t.mode});t.abort=new AbortController();
    try{
      if(samples.length/rate<.25)throw new Error('录音太短，请再试一次');
      const endpoint=t.mode==='recognize'?'/api/speech/recognize':`/api/speech/assess?text=${encodeURIComponent(t.text)}`;
      const r=await fetch(endpoint,{method:'POST',headers:{'Content-Type':'audio/wav'},body:wavFromFloat(samples,rate),signal:t.abort.signal});const data=await r.json();if(!r.ok)throw new Error(data.error||'语音处理失败');
      if(this.current===t){this.current=null;this.emit('capture',{session:t.session,state:'done',mode:t.mode,...data});}
    }catch(error){if(this.current===t){this.current=null;this.emit('capture',{session:t.session,state:'error',message:error.message});}}
  }
}
