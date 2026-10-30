import test from 'node:test';
import assert from 'node:assert/strict';
import {downloadModel} from '../assets/avatar/model-download.js';

test('preview chunks reconstruct exact bytes and retry only a failed chunk',async()=>{
  const source=Uint8Array.from({length:6200},(_,i)=>i%251),hits=new Map();
  const result=await downloadModel('https://example.test/model.glb',{fetchImpl:async(url,options)=>{
    if(options?.method==='HEAD')return new Response(null,{headers:{'X-Preview-Model-Bytes':source.length,'X-Preview-Chunk-Size':2048,ETag:'revision1'}});
    const index=Number(new URL(url).searchParams.get('previewPart'));
    hits.set(index,(hits.get(index)||0)+1);
    if(index===1&&hits.get(index)===1)throw new TypeError('Network lost');
    return new Response(source.slice(index*2048,(index+1)*2048),{headers:{'X-Preview-Model-ETag':'revision1'}});
  }});
  assert.deepEqual(new Uint8Array(result),source);assert.equal(hits.get(1),2);assert.equal(hits.get(0),1);
});
test('native servers without HEAD still load the original model',async()=>{
  const result=await downloadModel('/model.glb',{fetchImpl:async(_,options)=>options?.method==='HEAD'?new Response(null,{status:403}):new Response(new Uint8Array([1,2,3]))});
  assert.deepEqual([...new Uint8Array(result)],[1,2,3]);
});
test('model revisions cannot silently mix during download',async()=>{
  await assert.rejects(downloadModel('https://example.test/model.glb',{fetchImpl:async(_,options)=>options?.method==='HEAD'
    ?new Response(null,{headers:{'X-Preview-Model-Bytes':2048,'X-Preview-Chunk-Size':2048,ETag:'before'}})
    :new Response(new Uint8Array(2048),{headers:{'X-Preview-Model-ETag':'after'}})}),/发生变化/);
});
