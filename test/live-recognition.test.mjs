import test from 'node:test';
import assert from 'node:assert/strict';
import {Readable} from 'node:stream';
import {liveRecognitionHandler} from '../services/live-recognition.mjs';
function harness(){
 let closed=0,bytes=0;
 const handler=liveRecognitionHandler({factory:()=>({send:async b=>{bytes+=b.length;},snapshot:()=>({text:'I want'}),end:async()=>({text:'I want an apple.'}),close:()=>closed++})});
 async function call(action,id='',body=Buffer.alloc(0),type='application/octet-stream'){
  const req=Readable.from([body]);req.method='POST';req.headers={'content-type':type};
  let status,json;const res={writeHead(n){status=n;return this;},end(s){json=JSON.parse(s);}};
  await handler(req,res,new URL(`http://localhost/api/speech/recognize?live=${action}&id=${id}`));return {status,...json};
 }
 return {call,stats:()=>({closed,bytes})};
}
test('real PCM chunks return partial text; final closes the turn and cannot replay',async()=>{
 const h=harness(),start=await h.call('start');assert.match(start.id,/^[a-f0-9]{48}$/);
 assert.equal((await h.call('chunk',start.id,Buffer.alloc(6400))).text,'I want');
 assert.equal((await h.call('end',start.id)).text,'I want an apple.');
 assert.equal((await h.call('chunk',start.id,Buffer.alloc(6400))).status,400);
 assert.deepEqual(h.stats(),{closed:1,bytes:6400});
});
test('cancellation, malformed audio, unknown identifiers and bounded sessions',async()=>{
 const h=harness(),a=await h.call('start'),b=await h.call('start');
 assert.equal((await h.call('start')).status,429);
 assert.equal((await h.call('chunk',a.id,Buffer.alloc(3))).status,400);
 assert.equal((await h.call('cancel',b.id)).status,200);
 assert.equal((await h.call('chunk','invalid')).status,400);
 assert.equal(h.stats().bytes,0);
});
