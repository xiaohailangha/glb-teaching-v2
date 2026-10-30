import test from 'node:test';
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import {signedUrl,pcmWave,readWave,validateAudio,alignmentCues,phoneViseme,speechText} from '../services/tencent-speech.mjs';
import {trustedRequest} from '../services/speech-http.mjs';
import {wavFromFloat} from '../assets/avatar/cloud-speech.js';

test('Tencent signing uses raw sorted values, then percent-encodes transport values',()=>{
  const params={ref_text:'I like apples.',timestamp:123,nonce:2};
  const url=new URL(signedUrl('soe.cloud.tencent.com/soe/api/123',params,'test-key'));
  assert.equal(url.searchParams.get('ref_text'),'I like apples.');
  assert.equal(url.searchParams.get('signature'),crypto.createHmac('sha1','test-key').update('soe.cloud.tencent.com/soe/api/123?nonce=2&ref_text=I like apples.&timestamp=123').digest('base64'));
  const tts=new URL(signedUrl('tts.cloud.tencent.com/stream_wsv2',{Text:'苹果 & apple'},'test-key',{tts:true}));
  assert.equal(tts.searchParams.get('Signature'),crypto.createHmac('sha1','test-key').update('GETtts.cloud.tencent.com/stream_wsv2?Text=苹果 & apple').digest('base64'));
});
test('recording resamples 48k/44.1k to valid PCM16 and rejects silent or malformed uploads',()=>{
  for(const rate of [48000,44100,16000]){
    const samples=Float32Array.from({length:rate},(_,i)=>Math.sin(i*2*Math.PI*440/rate)*.2);
    const wav=Buffer.from(wavFromFloat(samples,rate));assert.equal(validateAudio(wav).duration,1);
  }
  assert.throws(()=>validateAudio(pcmWave(Buffer.alloc(32000))),/没有听到/);
  assert.throws(()=>readWave(Buffer.from('not audio')),/PCM WAV/);
  const bad=pcmWave(Buffer.alloc(32000));bad.writeUInt32LE(48000,24);assert.throws(()=>readWave(bad),/16kHz/);
});
test('phoneme alignment respects real boundaries, silence, and missing phone data',()=>{
  const result={Words:[{PhoneInfos:[{Phone:'ae',MemBeginTime:100,MemEndTime:300},{Phone:'p',MemBeginTime:300,MemEndTime:380},{Phone:'ax',MemBeginTime:380,MemEndTime:440},{Phone:'l',MemBeginTime:440,MemEndTime:650}]}]};
  const aligned=alignmentCues(result,1);assert.equal(aligned.usable,true);
  assert.deepEqual(aligned.cues.map(c=>[c.time,c.id]),[[0,0],[.1,1],[.3,21],[.38,1],[.44,14],[.65,0]]);
  assert.equal(phoneViseme('bogus'),null);
  result.Words[0].PhoneInfos[1].Phone='bogus';assert.equal(alignmentCues(result,1).usable,false);
  assert.equal(alignmentCues({Words:[]},1).usable,false);
  assert.equal(phoneViseme('w','zh'),7);
  assert.equal(phoneViseme('y','zh'),6);
  const zh=alignmentCues({Words:[{PhoneInfos:[{Phone:'y',MemBeginTime:50,MemEndTime:100},{Phone:'i4',MemBeginTime:100,MemEndTime:1050}]}]},1,'zh');
  assert.equal(zh.usable,true);assert.equal(zh.phones.at(-1).end,1);
});
test('speech endpoints reject cross-site localhost spending and DNS rebinding',()=>{
  const req={socket:{remoteAddress:'127.0.0.1'},headers:{host:'localhost:5296',origin:'http://localhost:5296','sec-fetch-site':'same-origin'}};
  assert.equal(trustedRequest(req),true);
  assert.equal(trustedRequest({...req,headers:{...req.headers,origin:'https://evil.example'}}),false);
  assert.equal(trustedRequest({...req,headers:{host:'evil.example'}}),false);
  assert.equal(trustedRequest({...req,socket:{remoteAddress:'10.0.0.1'}}),false);
  assert.throws(()=>speechText('<speak>text</speak>'));
});
