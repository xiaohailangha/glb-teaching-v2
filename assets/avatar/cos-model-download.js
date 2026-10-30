const hash=async bytes=>Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',bytes)),x=>x.toString(16).padStart(2,'0')).join('');
export function validateCloudManifest(m){
 if(m?.version!==1||! /^[a-f0-9]{64}$/.test(m.revision)||!Number.isSafeInteger(m.size)||m.size<=0||m.size>256*1024*1024||
    !Number.isSafeInteger(m.chunkSize)||m.chunkSize<1024||m.chunkSize>8*1024*1024||!Array.isArray(m.parts)||m.parts.length!==Math.ceil(m.size/m.chunkSize))throw Error('Invalid model manifest');
 let host;
 for(let i=0;i<m.parts.length;i++){
  const p=m.parts[i],u=new URL(p.url);
  if(u.protocol!=='https:'||u.username||u.password||!/^[-a-z0-9]+\.cos\.ap-[a-z]+\.myqcloud\.com$/.test(u.hostname)||
     (host&&host!==u.hostname)||p.size!==Math.min(m.chunkSize,m.size-i*m.chunkSize)||! /^[a-f0-9]{64}$/.test(p.sha256))throw Error('Invalid model part');
  host=u.hostname;
 }
 return m;
}
export async function downloadCloudModel(manifest,{fetchImpl=fetch,onProgress=()=>{},cacheStorage=globalThis.caches}={}){
 const m=validateCloudManifest(manifest),result=new Uint8Array(m.size),controller=new AbortController();
 const cacheName='glb-cos-model-v1-'+m.revision;
 let cache;try{cache=await cacheStorage?.open(cacheName);}catch{}
 let next=0,completed=0;
 async function worker(){
  while(next<m.parts.length&&!controller.signal.aborted){
   const index=next++,part=m.parts[index],cacheKey=new URL(`/__glb_model_cache__/${m.revision}/${index}`,globalThis.location?.origin||'https://glb-cache.invalid').href;
   let bytes;
   try{const hit=await cache?.match(cacheKey);if(hit){const b=await hit.arrayBuffer();if(b.byteLength===part.size&&await hash(b)===part.sha256)bytes=b;}}catch{}
   if(!bytes){
    let lastError;
    for(let attempt=0;attempt<3;attempt++){
     if(controller.signal.aborted)throw controller.signal.reason;
     const timeout=new AbortController(),timer=setTimeout(()=>timeout.abort(),60000);
     const cancel=()=>timeout.abort(controller.signal.reason);controller.signal.addEventListener('abort',cancel,{once:true});
     try{
      const r=await fetchImpl(part.url,{credentials:'omit',referrerPolicy:'no-referrer',signal:timeout.signal});
      if(!r.ok)throw Error('Model download failed');
      const b=await r.arrayBuffer();if(b.byteLength!==part.size||await hash(b)!==part.sha256)throw Error('Model integrity mismatch');
      bytes=b;break;
     }catch(e){lastError=e;}finally{clearTimeout(timer);controller.signal.removeEventListener('abort',cancel);}
    }
    if(!bytes)throw lastError;
    try{await cache?.put(cacheKey,new Response(bytes,{headers:{'Content-Type':'application/octet-stream'}}));}catch{/* Cache quotas or private mode must not prevent learning. */}
   }
   result.set(new Uint8Array(bytes),index*m.chunkSize);completed+=bytes.byteLength;onProgress(completed/m.size);
  }
 }
 try{await Promise.all(Array.from({length:Math.min(4,m.parts.length)},worker));}
 catch(e){controller.abort(e);throw e;}
 if(await hash(result)!==m.revision)throw Error('Model revision mismatch');
 try{for(const name of await cacheStorage?.keys()||[])if(name.startsWith('glb-cos-model-v1-')&&name!==cacheName)await cacheStorage.delete(name);}catch{}
 return result.buffer;
}
export async function tryCloudModel(manifestUrl,options={}){
 try{
  const r=await (options.fetchImpl||fetch)(manifestUrl,{cache:'no-store',signal:AbortSignal.timeout(20000)});
  if(!r.ok)return null;
  return await downloadCloudModel(await r.json(),options);
 }catch{return null;}
}
