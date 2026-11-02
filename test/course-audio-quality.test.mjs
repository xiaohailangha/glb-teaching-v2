import test from 'node:test';
import assert from 'node:assert/strict';
import {sameSpeech,validateWordAlignment,isolateAlignedSpeech} from '../services/course-audio-quality.mjs';
import {pcmWave,readWave} from '../services/tencent-speech.mjs';

test('extra syllables, plural loss and different vowels cannot pass transcript validation',()=>{
 for(const [target,heard] of [['banana','banana na'],['bananas','banana'],['water','water netto'],['want',"won't"],['two','tool'],['some coffee','sun coffee']])assert.equal(sameSpeech(target,heard),false);
 assert.equal(sameSpeech('tea','T.'),true);
 assert.equal(sameSpeech('Two tickets, please.','2 tickets please'),true);
 assert.equal(sameSpeech('I am ready.',"I'm ready."),false);
});
const word=(Word,start,end,score=98)=>({Word,MemBeginTime:start,MemEndTime:end,PronAccuracy:score,MatchTag:0,PhoneInfos:[{Phone:'ah'}]});
test('alignment requires complete lexical order and permits documented function-word reduction only in phrases',()=>{
 assert.doesNotThrow(()=>validateWordAlignment('a banana',[word('a',100,200,84),word('banana',200,800)]));
 assert.throws(()=>validateWordAlignment('a',[word('a',100,200,84)]));
 assert.throws(()=>validateWordAlignment('a banana',[word('a',100,200,84),word('banana',200,800,84)]));
 assert.throws(()=>validateWordAlignment('banana',[word('banana',100,800),word('na',800,900)]));
 assert.throws(()=>validateWordAlignment('two words',[word('two',100,500),word('words',400,800)]));
});
test('crop keeps the complete aligned word and removes a later repeated tail without changing timing scale',()=>{
 const pcm=Buffer.alloc(32000);
 for(let i=0;i<16000;i++)pcm.writeInt16LE(i>=3200&&i<8000?1000:i>=12000?5000:0,i*2);
 const result=isolateAlignedSpeech(pcmWave(pcm),[word('banana',200,500)],[{time:.2,id:21},{time:.5,id:0},{time:.75,id:19}]);
 const output=readWave(result.wav);
 assert.ok(output.duration<.7);
 assert.ok(!result.cues.some(c=>c.id===19));
 assert.ok(Math.abs(result.wordTimings[0].end-result.wordTimings[0].start-.3)<1e-9);
 for(let i=0;i<output.pcm.length;i+=2)assert.ok(Math.abs(output.pcm.readInt16LE(i))<=1000);
 assert.equal(result.cues.at(-1).id,0);
});
