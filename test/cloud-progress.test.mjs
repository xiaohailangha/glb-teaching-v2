import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import crypto from 'node:crypto';
import {LearningStore} from '../services/learning-store.mjs';
import {CloudCurriculum} from '../services/cloud-curriculum.mjs';

test('skipped final exercise resumes at the missing step and unlocks only after real completion',async t=>{
 const directory=fs.mkdtempSync(path.join(os.tmpdir(),'snow-cloud-progress-'));
 const store=new LearningStore({directory});
 t.after(()=>{store.close();fs.rmSync(directory,{recursive:true,force:true});});
 const sign=async assets=>assets.map(a=>({...a,url:'https://example.test/resource'}));
 let c=new CloudCurriculum(store,{sign});
 const release=c.active(),course='N26-U001-L01',user='isolated-unlock-test';
 c.selectLevel(user,{level:1,revision:0,version:release});
 const lesson=c.lesson(course,release).lesson;
 let revision=0;
 const visit=s=>{
  const input={version:release,course,step:s.id};
  if(s.check){c.heard(user,{...input,audio:s.model});c.continueListening(user,input);}
  else if(s.audio)c.heard(user,{...input,audio:s.audio});
  revision=c.saveProgress(user,{...input,revision}).revision;
 };
 for(const s of lesson.steps)if(!s.id.endsWith('-S027')&&!s.id.endsWith('-S028'))visit(s);
 let state=c.state(user,release),progress=state.progress[0];
 assert.equal(progress.step,course+'-S029');
 assert.equal(progress.pendingStep,course+'-S027');
 assert.equal(progress.completed,false);
 assert.equal(progress.visitedSteps.length,27);
 assert.deepEqual(state.evidence.completedCourses,[]);
 assert.throws(()=>c.checkCourse(user,'N26-U001-L02',release),{status:403});
 // Reopen against the same stored progress, as after a refresh/relogin.
 c=new CloudCurriculum(store,{sign});
 assert.equal(c.state(user,release).progress[0].pendingStep,course+'-S027');
 visit(lesson.steps.find(s=>s.id.endsWith('-S027')));
 assert.equal(c.state(user,release).progress[0].pendingStep,course+'-S028');
 assert.throws(()=>c.checkCourse(user,'N26-U001-L02',release),{status:403});
 visit(lesson.steps.find(s=>s.id.endsWith('-S028')));
 state=c.state(user,release);
 assert.equal(state.progress[0].pendingStep,null);
 assert.equal(state.progress[0].completed,true);
 assert.deepEqual(state.evidence.completedCourses,[course]);
 assert.equal(state.evidence.learnedWords,0);
 await c.detail('N26-U001-L02',release,{user});
 await c.media('N26-U001-L02',release,{user});
 assert.throws(()=>c.checkCourse(user,'N26-U001-L03',release),{status:403});
 visit(lesson.steps[0]);
 assert.deepEqual(new CloudCurriculum(store,{sign}).state(user,release).evidence.completedCourses,[course]);
 assert.deepEqual(c.state('another-user',release).progress,[]);
});

test('explicit arrow skips persist without heard/mastery claims and article delivery omits isolated drills',async t=>{
 const directory=fs.mkdtempSync(path.join(os.tmpdir(),'snow-arrow-progress-'));
 const store=new LearningStore({directory});
 t.after(()=>{store.close();fs.rmSync(directory,{recursive:true,force:true});});
 const c=new CloudCurriculum(store,{sign:async assets=>assets.map(a=>({...a,url:'https://example.test/resource'}))});
 const release=c.active(),user='skip-test',course='N26-U001-L01';
 c.selectLevel(user,{level:1,revision:0,version:release});
 let revision=0;
 for(const s of c.lesson(course,release).lesson.steps){
  const result=await c.route('curriculum/skip',user,{version:release,course,step:s.id,revision},new URL('https://example.test'));
  assert.equal(result.awardMastery,false);revision=result.revision;
 }
 const state=new CloudCurriculum(store).state(user,release);
 assert.deepEqual(state.evidence.completedCourses,[course]);
 assert.equal(state.evidence.learnedWords,0);
 assert.equal(state.evidence.independentMastery,false);
 assert.equal(state.progress[0].skippedSteps.length,29);
 assert.equal(store.db.prepare('SELECT count(*) n FROM formal_heard WHERE user_id=?').get(user).n,0);
 assert.equal(store.db.prepare('SELECT count(*) n FROM formal_steps WHERE user_id=?').get(user).n,0);
 assert.equal(store.db.prepare('SELECT count(*) n FROM curriculum_evidence WHERE user_id=?').get(user).n,0);
 const descriptor=await c.detail('N26-U001-L02',release,{user});
 const bytes=Buffer.from(descriptor.inlineDocument.base64,'base64');
 assert.equal(crypto.createHash('sha256').update(bytes).digest('hex'),descriptor.inlineDocument.sha256);
 const document=JSON.parse(bytes);
 assert.equal(document.lesson.steps.length,26);
 assert.equal(document.lesson.steps.some(s=>s.display==='a'),false);
 assert.equal(document.lesson.steps.filter(s=>s.display==='an').length,3);
 assert.equal(document.lesson.checks.some(c=>c.id.endsWith('-C001')),false);
 assert.equal(document.lesson.checks.some(c=>c.id.endsWith('-C002')),true);
 assert.equal(document.audio.some(a=>a.text==='a'),false);
 assert.equal(document.audio.some(a=>a.text==='an'),true);
 assert.equal(document.audio.some(a=>a.text==='an apple'),true);
 assert.equal(document.audio.some(a=>a.text==='a banana'),true);
 assert.deepEqual(document.lesson.helpBranches,[]);
 assert.equal(document.lesson.actualWords.find(w=>w.word==='a').standalonePreview,false);
 assert.notEqual(document.lesson.actualWords.find(w=>w.word==='an').standalonePreview,false);
 const r=c.runtime(release),original=JSON.parse(fs.readFileSync(path.join(r.dir,r.index.lessons['N26-U001-L02'].path)));
 assert.equal(original.lesson.steps.length,29);
 assert.equal(original.lesson.steps[1].display,'a');
 assert.equal(document.audio.find(a=>a.text==='an').sha256,original.audio.find(a=>a.text==='an').sha256);
 await assert.rejects(c.detail('N26-U001-L03',release,{user}),{status:403});
 assert.deepEqual(c.state('another-user',release).progress,[]);
});
