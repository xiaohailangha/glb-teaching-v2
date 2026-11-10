import test from 'node:test';import assert from 'node:assert/strict';import fs from 'node:fs';import os from 'node:os';import path from 'node:path';
import {TeachingPilot,pilotDecision,pilotTokens} from '../services/teaching-pilot.mjs';
import {LearningStore} from '../services/learning-store.mjs';import {CloudCurriculum} from '../services/cloud-curriculum.mjs';
const high=text=>({PronAccuracy:95,PronCompletion:1,Words:pilotTokens(text).map(Word=>({Word,MatchTag:0,PronAccuracy:95,PhoneInfos:[]}))});
function fixture(t){const directory=fs.mkdtempSync(path.join(os.tmpdir(),'stable-teaching-'));const store=new LearningStore({directory});t.after(()=>{store.close();fs.rmSync(directory,{recursive:true,force:true});});const curriculum=new CloudCurriculum(store);let heard='',score=null;const pilot=new TeachingPilot(store,curriculum,{recognizer:async()=>({text:heard}),assessor:async(_,{text})=>score||high(text)});pilot.fallbackRecognizer=pilot.recognizer;return {store,curriculum,pilot,set:(text,result=null)=>{heard=text;score=result;}};}
const wav=()=>{const b=Buffer.alloc(44+32000);b.write('RIFF');b.writeUInt32LE(b.length-8,4);b.write('WAVEfmt ',8);b.writeUInt32LE(16,16);b.writeUInt16LE(1,20);b.writeUInt16LE(1,22);b.writeUInt32LE(16000,24);b.writeUInt32LE(32000,28);b.writeUInt16LE(2,32);b.writeUInt16LE(16,34);b.write('data',36);b.writeUInt32LE(32000,40);for(let i=44;i<b.length;i+=2)b.writeInt16LE(Math.round(Math.sin(i*.1)*5000),i);return b.toString('base64');};
const url=new URL('https://example.test');
test('approved 29 stages have stable boards and complete ordered verified audio',t=>{
 const {pilot}=fixture(t);assert.equal(pilot.content.presentation,'stable-board/1');assert.deepEqual(pilot.content.lessons.map(l=>l.steps.length),[8,21]);
 assert.ok(!JSON.stringify(pilot.content).includes('老师'));
 for(const l of pilot.content.lessons){const d=pilot.document('u',l.id);assert.equal(d.words.length,l.id.includes('006')?8:19);
  for(const s of l.steps){assert.ok(Array.isArray(s.board));assert.equal(s.interaction,undefined);
   for(const id of [...s.beforeAudio,...s.afterAudio,...s.reviewAudio]){const a=pilot.asset(id,l.id);assert.equal(a.voice,403008);assert.ok(a.cues.length>1);assert.equal(a.size,Buffer.from(a.inlineAudio,'base64').length);assert.ok(a.speechEndMs>0);}
   if(s.answers.length&&!s.reviewTarget){const last=pilot.content.assets[s.beforeAudio.at(-1)];assert.equal(last.language,'zh');}
  }
 }
 const complex=pilot.content.lessons[1],by=id=>complex.steps.find(s=>s.id===id);
 assert.deepEqual(by('B04').answers,['though']);assert.equal(by('B11').optional,true);assert.equal(by('B11').optionalWindowMs,undefined);
 assert.equal(by('B09').holdAfter,true);assert.equal(by('B14').holdAfter,true);
 assert.deepEqual(by('B08').models,['Despite the difficulty, I can try.']);
 for(const id of ['B16','B19'])assert.equal(pilot.content.assets[by(id).afterAudio.at(-1)].language,'en');
 assert.throws(()=>pilot.asset('../../secret',complex.id),{status:404});
});
test('meaning and structure corrections retain the exact position and original expression',()=>{
 let r=pilotDecision({answers:['I want an apple and a banana.']},'I want an apple or a banana.',null);assert.equal(r.messageKey,'and');assert.equal(r.target,'an apple and a banana');
 r=pilotDecision({answers:['Despite the difficulty, I can try.']},'Despite this is difficult I can try',null);assert.equal(r.type,'structure');assert.equal(r.target,'despite the difficulty');
 const text='I want an apple and a banana.',score=high(text);score.Words[6].PronAccuracy=20;score.Words[6].PhoneInfos=[{Phone:'ah',MatchTag:0,PronAccuracy:20}];r=pilotDecision({answers:[text]},text,score);assert.equal(r.index,6);assert.equal(r.word,'banana');assert.equal(r.phone,'ə');
 assert.equal(pilotDecision({answers:[text]},'',null).status,'unclear');assert.equal(pilotDecision({answers:[text]},text,null).status,'unclear');
});
test('independent recognition runs with assessment and alternatives are assessed against their actual words',async t=>{
 const {pilot}=fixture(t);let resolveAsr,resolveSoe,asr=false,soe=false;
 pilot.recognizer=()=>{asr=true;return new Promise(r=>resolveAsr=r);};pilot.assessor=()=>{soe=true;return new Promise(r=>resolveSoe=r);};
 const expected='I want an apple or a banana.';pilot.fallbackRecognizer=async()=>({text:expected});
 const pending=pilot.oral('u',{course:'N26-U006-L04',revision:pilot.content.revision,step:'A05',attempt:'parallel-001',wav:wav()});
 assert.ok(asr&&soe);resolveAsr({text:'If '+expected});resolveSoe(high(expected));const r=await pending;assert.equal(r.status,'passed');assert.equal(r.firstHeard,'If '+expected);
 const expression='This is difficult. However, I can try.',assessed=[];pilot.recognizer=async()=>({text:expression});pilot.assessor=async(_,{text})=>{assessed.push(text);return high(text);};
 const alternative=await pilot.oral('a',{course:'N26-U084-L01',revision:pilot.content.revision,step:'B13',attempt:'alternate-001',reference:'Although this is difficult, I can try.',wav:wav()});
 assert.equal(alternative.status,'passed');assert.equal(alternative.evidenceLevel,'supported-expression');assert.equal(assessed.at(-1),expression);
});
test('local pass does not complete the original task, and correction tickets are user and step bound',async t=>{
 const {pilot,set}=fixture(t),course='N26-U006-L04',revision=pilot.content.revision,base={course,revision,step:'A03',wav:wav()};
 set('I want an apple or a banana.');const bad=await pilot.oral('u',{...base,attempt:'repair-start'});assert.equal(bad.status,'repair');
 assert.ok(bad.audio.every(id=>typeof id==='string'));set(bad.target);const local=await pilot.oral('u',{...base,attempt:'repair-local',repair:bad.repair});
 assert.equal(local.returnToSentence,true);assert.ok(local.audio.every(id=>pilot.content.assets[id].language==='zh'));
 await assert.rejects(pilot.route('pilot/progress','u',{...base,outcome:'passed',attempt:local.attempt},url),{status:400});
 await assert.rejects(pilot.oral('other',{...base,attempt:'repair-cross',repair:bad.repair}),{status:409});
 set(bad.original);const full=await pilot.oral('u',{...base,attempt:'repair-final'});assert.equal(full.status,'passed');assert.ok(!full.returnToSentence);
 await pilot.route('pilot/progress','u',{...base,outcome:'passed',attempt:full.attempt},url);assert.equal(pilot.document('u',course).review.length,0);
});
test('bounded local retries preserve needs-review and never manufacture a pass',async t=>{
 const {pilot,set}=fixture(t),base={course:'N26-U006-L04',revision:pilot.content.revision,step:'A03',wav:wav()};
 set('I want an apple or a banana.');let r=await pilot.oral('u',{...base,attempt:'bounded-first'});
 for(let i=0;i<2;i++){set('an apple or a banana');r=await pilot.oral('u',{...base,attempt:'bounded-local-'+i,repair:r.repair});}
 assert.equal(r.status,'assisted');assert.equal(r.evidenceLevel,'needs-review');
 await assert.rejects(pilot.route('pilot/progress','u',{...base,outcome:'passed',attempt:r.attempt},url),{status:400});
 set('I want an apple or a banana.');r=await pilot.oral('u',{...base,attempt:'bounded-assisted',assistance:r.attempt});assert.equal(r.status,'guided-complete');
 await pilot.route('pilot/progress','u',{...base,outcome:'assisted',attempt:r.attempt},url);
 const summary=await pilot.route('pilot/summary','u',{course:base.course},url);assert.equal(summary.counts.supported,0);assert.ok(summary.review.length);
});
test('targeted relationship review cannot accept an unrelated phrase and clears only the repaired source',async t=>{
 const {pilot,set}=fixture(t),base={course:'N26-U084-L01',revision:pilot.content.revision,wav:wav()};
 await assert.rejects(pilot.oral('u',{...base,step:'B20',attempt:'no-review-001'}),{status:409});
 set('except friends');const bad=await pilot.oral('u',{...base,step:'B18',attempt:'weak-among-001'});assert.equal(bad.status,'repair');
 set('against the proposal');const wrong=await pilot.oral('u',{...base,step:'B20',reference:'against the proposal',attempt:'review-wrong'});assert.notEqual(wrong.status,'passed');
 set('among friends');const right=await pilot.oral('u',{...base,step:'B20',reference:'among friends',attempt:'review-right'});assert.equal(right.status,'passed');assert.equal(right.reviewSource,'B18');
 assert.ok(!pilot.unresolved('u',base.course).has('B18'));
});
test('entire lessons save only trial progress; formal learning and other users remain untouched',async t=>{
 const {pilot,curriculum,set,store}=fixture(t);let n=0;
 for(const l of pilot.content.lessons){const user='trial-'+l.id;for(const s of l.steps){let outcome='heard',attempt;
   if(s.answers.length&&!s.reviewTarget){set(s.answers[0]);const r=await pilot.oral(user,{course:l.id,revision:pilot.content.revision,step:s.id,attempt:'full-course-'+(++n),wav:wav()});assert.equal(r.status,'passed');outcome='passed';attempt=r.attempt;}
   await pilot.route('pilot/progress',user,{course:l.id,revision:pilot.content.revision,step:s.id,outcome,attempt},url);
  }assert.equal(pilot.document(user,l.id).visits.length,l.steps.length);assert.equal(pilot.document('other',l.id).visits.length,0);
 }
 assert.deepEqual(curriculum.state('u').progress,[]);assert.equal(curriculum.state('u').evidence.learnedWords,0);
 assert.equal(store.db.prepare('SELECT count(*) n FROM formal_steps').get().n,0);assert.equal(store.db.prepare('SELECT count(*) n FROM curriculum_evidence').get().n,0);
 await assert.rejects(pilot.route('pilot/action','u',{},url),{status:410});
});
