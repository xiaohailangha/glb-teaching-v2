// Preview servers can advertise resumable chunks; local/native servers keep normal loading.
import {tryCloudModel} from './cos-model-download.js';
export async function downloadModel(url, {fetchImpl=fetch, onProgress=()=>{},cloudManifestUrl=null}={}) {
  if(cloudManifestUrl){const cloud=await tryCloudModel(cloudManifestUrl,{fetchImpl,onProgress});if(cloud)return cloud;}
  const controller=new AbortController();
  async function read(target, options={}) {
    let error;
    for(let attempt=0;attempt<3;attempt++) {
      if(controller.signal.aborted)throw controller.signal.reason;
      const timeout=new AbortController();
      const cancel=()=>timeout.abort(controller.signal.reason);
      controller.signal.addEventListener('abort',cancel,{once:true});
      const timer=setTimeout(()=>timeout.abort(new Error('模型下载超时')),120000);
      try {
        const response=await fetchImpl(target,{...options,signal:timeout.signal});
        if(!response.ok)throw new Error(`人物模型下载失败 (${response.status})`);
        const bytes=options.method==='HEAD'?null:await response.arrayBuffer();
        return {response,bytes};
      }catch(e){error=e;}finally{clearTimeout(timer);controller.signal.removeEventListener('abort',cancel);}
    }
    throw error;
  }
  let head;
  // Native bundle servers may reject HEAD. No assumption about range support.
  try {head=await fetchImpl(url,{method:'HEAD',signal:AbortSignal.timeout(10000)});}catch{}
  const size=Number(head?.headers.get('X-Preview-Model-Bytes'));
  const chunkSize=Number(head?.headers.get('X-Preview-Chunk-Size'));
  const revision=head?.headers.get('ETag');
  if(!head?.ok||!Number.isSafeInteger(size)||size<=0||size>256*1024*1024||
      !Number.isSafeInteger(chunkSize)||chunkSize<1024||chunkSize>8*1024*1024||!revision) {
    return (await read(url)).bytes;
  }
  const result=new Uint8Array(size);
  const count=Math.ceil(size/chunkSize);
  let next=0,completed=0;
  async function worker() {
    while(next<count&&!controller.signal.aborted) {
      const index=next++,partUrl=new URL(url,globalThis.location?.href||'http://localhost/');
      partUrl.searchParams.set('previewPart',String(index));
      const {response,bytes}=await read(partUrl.href);
      if(response.headers.get('X-Preview-Model-ETag')!==revision||bytes.byteLength!==Math.min(chunkSize,size-index*chunkSize)) {
        throw new Error('人物文件在下载期间发生变化，请重试');
      }
      result.set(new Uint8Array(bytes),index*chunkSize);
      completed+=bytes.byteLength;onProgress(completed/size);
    }
  }
  try {await Promise.all(Array.from({length:Math.min(3,count)},worker));}
  catch(error){controller.abort(error);throw error;}
  return result.buffer;
}
