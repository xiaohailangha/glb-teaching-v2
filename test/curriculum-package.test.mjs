import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import crypto from 'node:crypto';
import {auditContentPackage,auditContentPackages} from '../services/curriculum-package.mjs';
import {formalPlan,formalPlanHash,formalPlanVersion} from '../services/formal-curriculum.mjs';

function fixture(t){
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'snow-intake-'));
 t.after(()=>fs.rmSync(dir,{recursive:true,force:true}));
 const c=formalPlan.courses[0],steps=[
  {id:c.id+'-S1',course:c.id,stage:1,phase:'开场',display:'',audio:'intro',avatar:{phase:'meaning'}},
  {id:c.id+'-S2',course:c.id,stage:2,phase:'示范',display:'apple',audio:'apple',avatar:{phase:'model'}},
  {id:c.id+'-S3',course:c.id,stage:2,phase:'跟读',display:'apple',audio:'',model:'apple',check:'check',supported:true,capture:'immediate_on_same_display_after_model',avatar:{phase:'listen'}},
  ...[3,4,5,6].map(stage=>({id:c.id+'-S'+(stage+1),course:c.id,stage,phase:'讲解',display:'',audio:'intro',avatar:{phase:'meaning'}})),
 ];
 const status={release:'not_published'};
 const lesson={schema:'snow-speaks.content/1',courseId:c.id,unitId:c.unit,category:c.category,title:c.title,planHash:formalPlanHash,planVersion:formalPlanVersion,sourceCourseHash:crypto.createHash('sha256').update(JSON.stringify(c)).digest('hex'),newWords:c.words,prerequisites:c.prerequisites,status,steps,sixStages:[1,2,3,4,5,6].map(id=>({id,steps:steps.filter(s=>s.stage===id).map(s=>s.id)})),checks:[{id:'check',course:c.id,kind:'teaching',answers:['apple'],supported:true,independentEligible:false,audio:[]}],actualWords:[{key:'apple',word:'apple',ipa:'/ˈæpəl/',audio:'apple'},{key:'banana',word:'banana',ipa:'/bəˈnænə/',audio:'banana'}],summary:{wordSource:'actualWords',wholeWordAndIpaClickable:true},helpBranches:[]};
 const pkg={schema:'snow-speaks.content-package/1',id:'test-draft',baseline:{planSha256:formalPlanHash},courses:[{courseId:c.id,title:c.title,file:'lesson.json',status}],audio:[{id:'intro',language:'zh',text:'认识水果',asset:null},{id:'apple',language:'en',text:'apple',asset:null},{id:'banana',language:'en',text:'banana',asset:null}]};
 const save=()=>{fs.writeFileSync(path.join(dir,'package.json'),JSON.stringify(pkg));fs.writeFileSync(path.join(dir,'lesson.json'),JSON.stringify(lesson));};save();
 return {dir,pkg,lesson,save};
}

test('valid draft intake reports missing media and never promotes author claims to playback',t=>{
 const f=fixture(t),r=auditContentPackage(f.dir);
 assert.equal(r.contentValid,true);assert.equal(r.requiredAudio,3);assert.equal(r.missingAudio,3);assert.equal(r.playable,false);assert.equal(r.published,false);
 f.pkg.audio.forEach(a=>a.asset={url:'https://unverified.example/asset.wav',status:'verified'});f.save();
 assert.equal(auditContentPackage(f.dir).playable,false);
});
test('wrong baseline, edited scope and pre-model practice are rejected',t=>{
 const f=fixture(t);f.pkg.baseline.planSha256='wrong';f.lesson.title='改名';f.lesson.newWords=['orange'];f.lesson.steps[1].display='banana';f.save();
 const r=auditContentPackage(f.dir);assert.equal(r.contentValid,false);
 assert.ok(r.errors.some(e=>e.includes('规划哈希')));assert.ok(r.errors.some(e=>e.includes('正式名称')));assert.ok(r.errors.some(e=>e.includes('首教')));assert.ok(r.errors.some(e=>e.includes('尚未示范')));
});
test('support cannot claim independence and foreign media vocabulary cannot leak into a lesson',t=>{
 const f=fixture(t);f.lesson.checks[0].independentEligible=true;f.pkg.audio.find(a=>a.id==='apple').text='orange';f.save();
 const r=auditContentPackage(f.dir);assert.equal(r.contentValid,false);assert.ok(r.errors.some(e=>e.includes('独立掌握')));assert.ok(r.errors.some(e=>e.includes('漏列 orange')));
});
test('intake rejects a path escaping the authoring package',t=>{
 const f=fixture(t);f.pkg.courses[0].file='../'+path.basename(f.dir)+'/lesson.json';f.save();
 // Resolving back inside the same root is allowed; the final real path controls.
 assert.equal(auditContentPackage(f.dir).contentValid,true);
 f.pkg.courses[0].file=path.join(f.dir,'lesson.json');f.save();
 assert.throws(()=>auditContentPackage(f.dir),/路径无效/);
 const outside=f.dir+'-outside.json';fs.writeFileSync(outside,'{}');t.after(()=>fs.unlinkSync(outside));
 f.pkg.courses[0].file='../'+path.basename(outside);f.save();
 assert.throws(()=>auditContentPackage(f.dir),/路径越界/);
});

function countingFixture(t,id='N26-U012-L01'){
 const f=fixture(t),c=formalPlan.courses.find(c=>c.id===id),l=f.lesson;
 Object.assign(l,{courseId:c.id,unitId:c.unit,category:c.category,title:c.title,sourceCourseHash:crypto.createHash('sha256').update(JSON.stringify(c)).digest('hex'),newWords:c.words,prerequisites:c.prerequisites});
 for(const step of l.steps){step.id=step.id.replace(/^N26-U001-L01/,c.id);step.course=c.id;if(step.display)step.display='one';}
 l.sixStages=[1,2,3,4,5,6].map(id=>({id,steps:l.steps.filter(s=>s.stage===id).map(s=>s.id)}));
 l.checks[0].course=c.id;l.checks[0].answers=['one'];
 l.actualWords=[{key:'one',word:'one',ipa:'/wʌn/',audio:'apple'}];
 f.pkg.audio.find(a=>a.id==='apple').text='one';
 Object.assign(f.pkg.courses[0],{courseId:c.id,title:c.title});
 if(id==='N26-U012-L01')l.requiredTaughtWords=[{key:'one',sourceCourse:'N26-U006-L03',planHash:formalPlanHash}];
 f.save();return f;
}

test('earlier unique first-teaching references extend only their key and stay runtime blocked',t=>{
 const source=countingFixture(t,'N26-U006-L03'),current=countingFixture(t);
 const original=JSON.stringify(formalPlan.courses.find(c=>c.id===current.lesson.courseId));
 const result=auditContentPackages([source.dir,current.dir]);
 assert.equal(result.contentValid,true);
 const intake=result.packages[1];
 assert.equal(intake.lessons[0].runtimeStatus,'needs_runtime_taught_word_guard');
 assert.deepEqual(intake.lessons[0].requiredTaughtWords,current.lesson.requiredTaughtWords);
 assert.ok(intake.blockers.includes('needs_runtime_taught_word_guard'));
 assert.equal(intake.playable,false);assert.equal(intake.published,false);
 assert.equal(JSON.stringify(formalPlan.courses.find(c=>c.id===current.lesson.courseId)),original);
 assert.deepEqual(current.lesson.prerequisites,['N26-U003']);
});

test('missing, stale and conflicting source contents cannot prove taught surface forms',t=>{
 const source=countingFixture(t,'N26-U006-L03'),current=countingFixture(t);
 assert.equal(auditContentPackage(current.dir).contentValid,false);
 const stale=structuredClone(source.lesson);stale.planHash='old';
 assert.equal(auditContentPackage(current.dir,{sourceLessons:[stale]}).contentValid,false);
 const different=structuredClone(source.lesson);different.actualWords[0].word='ones';
 const result=auditContentPackage(current.dir,{sourceLessons:[source.lesson,different]});
 assert.equal(result.contentValid,false);assert.ok(result.errors.some(e=>e.includes('一致版本的源课')));
});

test('a reference cannot import unintroduced inflections or unrelated word keys',t=>{
 const source=countingFixture(t,'N26-U006-L03'),current=countingFixture(t);
 current.lesson.actualWords.push({key:'two',word:'two',ipa:'/tuː/',audio:'apple'});current.save();
 let result=auditContentPackage(current.dir,{sourceLessons:[source.lesson]});
 assert.ok(result.errors.some(e=>e.includes('超出前置范围 two')));
 current.lesson.actualWords.pop();current.lesson.actualWords[0].word='ones';current.save();
 result=auditContentPackage(current.dir,{sourceLessons:[source.lesson]});
 assert.equal(result.contentValid,false);assert.ok(result.errors.some(e=>e.includes('复用词形未在源课实际教过 ones')));
});

test('first-teaching references reject wrong source, later or current lessons, old plan, duplicates and B1.01',t=>{
 const source=countingFixture(t,'N26-U006-L03'),current=countingFixture(t),valid=current.lesson.requiredTaughtWords[0];
 for(const invalid of [
  [{...valid,key:'unknown'}],[{...valid,sourceCourse:'B1.01-L01'}],
  [{...valid,sourceCourse:'N26-U003-L01'}],[{...valid,planHash:'old'}],
  [{key:'zero',sourceCourse:'N26-U012-L01',planHash:formalPlanHash}],
  [{key:'nine',sourceCourse:formalPlan.words.find(w=>w.key==='nine').course,planHash:formalPlanHash}],
  [valid,valid],{},
 ]){
  current.lesson.requiredTaughtWords=invalid;current.save();
  const result=auditContentPackage(current.dir,{sourceLessons:[source.lesson]});
  assert.equal(result.contentValid,false);assert.ok(result.errors.some(e=>e.includes('已首教词引用')));
 }
});

function surfaceFixture(t,id,key,word){
 const f=countingFixture(t,id),l=f.lesson;
 l.requiredTaughtWords=[];
 l.actualWords=[{key,word,ipa:'/test/',meaning:'本课词义',audio:'apple'}];
 for(const step of l.steps)if(step.display)step.display=word;
 l.checks[0].answers=[word];f.pkg.audio.find(a=>a.id==='apple').text=word;
 f.save();return f;
}
function explicitBeFixture(t){
 const source=surfaceFixture(t,'N26-U001-L03','be','is');
 const current=surfaceFixture(t,'N26-U019-L01','be','am'),l=current.lesson;
 l.requiredTaughtWords=[{key:'be',sourceCourse:source.lesson.courseId,planHash:formalPlanHash}];
 l.teachingScope={introduced:[{key:'be',surface:'am',meaning:'是，在，配合我时的形式',kind:'explicit_form_or_sense'}]};
 l.steps.splice(1,0,{id:l.courseId+'-meaning',course:l.courseId,stage:2,phase:'释义',display:'am',instruction:'是，在，配合我时的形式。',audio:'meaning',avatar:{phase:'meaning'}});
 current.pkg.audio.push({id:'meaning',text:'是，在，配合我时的形式。',language:'zh',asset:null});
 l.sixStages=[1,2,3,4,5,6].map(id=>({id,steps:l.steps.filter(s=>s.stage===id).map(s=>s.id)}));
 current.save();return {source,current};
}

test('a genuine local meaning-model-repeat sequence may teach another form of an allowed key',t=>{
 const {source,current}=explicitBeFixture(t);
 const result=auditContentPackage(current.dir,{sourceLessons:[source.lesson]});
 assert.deepEqual(result.errors,[]);assert.equal(result.contentValid,true);
 assert.equal(result.playable,false);assert.equal(result.published,false);
 assert.equal(result.lessons[0].runtimeStatus,'needs_runtime_taught_word_guard');
});

test('an explicit-form label cannot replace actual teaching, aligned scripts or supported repetition',t=>{
 const mutations=[
  f=>{f.lesson.steps[1].phase='讲解';},
  f=>{f.lesson.steps[1].instruction='';},
  f=>{f.pkg.audio.find(a=>a.id==='meaning').text='不匹配的中文';},
  f=>{f.pkg.audio.find(a=>a.id==='meaning').language='en';},
  f=>{f.pkg.audio.find(a=>a.id==='apple').text='is';},
  f=>{f.lesson.steps[2].display='is';},
  f=>{f.lesson.steps[3].model='meaning';},
  f=>{f.lesson.steps[3].capture='later';},
  f=>{f.lesson.steps[3].supported=false;},
  f=>{f.lesson.checks[0].independentEligible=true;},
  f=>{f.lesson.checks[0].kind='assessment';},
  f=>{f.lesson.checks[0].answers=['is'];},
  f=>{f.lesson.actualWords=[];},
  f=>{f.lesson.actualWords[0].meaning='';},
  f=>{f.lesson.teachingScope.introduced[0].key='unknown';},
  f=>{f.lesson.steps[1].stage=3;},
  f=>{f.lesson.steps.splice(2,0,{...f.lesson.steps[0],id:f.lesson.courseId+'-interrupt',stage:2});},
 ];
 for(const mutate of mutations){
  const {source,current}=explicitBeFixture(t);mutate(current);current.save();
  const result=auditContentPackage(current.dir,{sourceLessons:[source.lesson]});
  assert.equal(result.contentValid,false);
  assert.ok(result.errors.some(e=>e.includes('显式词形或义项缺少')));
 }
});

test('only real original prerequisites, not an arbitrary earlier lesson, can supply another surface',t=>{
 const {source,current}=explicitBeFixture(t);
 delete current.lesson.teachingScope;current.save();
 const earlier=surfaceFixture(t,'N26-U017-L01','be','am');
 let result=auditContentPackage(current.dir,{sourceLessons:[source.lesson,earlier.lesson]});
 assert.equal(result.contentValid,false);assert.ok(result.errors.some(e=>e.includes('复用词形')));
 const prerequisite=surfaceFixture(t,'N26-U003-L04','be','am');
 result=auditContentPackage(current.dir,{sourceLessons:[source.lesson,prerequisite.lesson]});
 assert.deepEqual(result.errors,[]);assert.equal(result.playable,false);
 const stale=structuredClone(prerequisite.lesson);stale.planHash='old';
 assert.equal(auditContentPackage(current.dir,{sourceLessons:[source.lesson,stale]}).contentValid,false);
 const conflict=structuredClone(prerequisite.lesson);conflict.actualWords[0].word='are';
 assert.equal(auditContentPackage(current.dir,{sourceLessons:[source.lesson,prerequisite.lesson,conflict]}).contentValid,false);
});

test('hyphenated words require the whole registered surface and IPA, not invented component entries',t=>{
 const f=surfaceFixture(t,'N26-U034-L02','t-shirt','t-shirt');
 assert.deepEqual(auditContentPackage(f.dir).errors,[]);
 f.lesson.steps[1].display='t-shark';f.pkg.audio.find(a=>a.id==='apple').text='t-shark';f.save();
 let result=auditContentPackage(f.dir);
 assert.equal(result.contentValid,false);assert.ok(result.errors.some(e=>e.includes('漏列 t-shark')));
 f.lesson.steps[1].display='t-shirt';f.pkg.audio.find(a=>a.id==='apple').text='t-shirt';
 f.lesson.actualWords=[{key:'t-shirt',word:'t',ipa:'/t/',properName:true},{key:'t-shirt',word:'shirt',ipa:'/ʃɜrt/',properName:true}];f.save();
 result=auditContentPackage(f.dir);assert.equal(result.contentValid,false);assert.ok(result.errors.some(e=>e.includes('漏列 t-shirt')));
});

test('word-card audio must pronounce its whole word even when another registered model is valid',t=>{
 const {source,current}=explicitBeFixture(t);
 current.pkg.audio.push({id:'wrong-card',text:'is',language:'en',asset:null});
 current.lesson.actualWords[0].audio='wrong-card';current.save();
 const result=auditContentPackage(current.dir,{sourceLessons:[source.lesson]});
 assert.equal(result.contentValid,false);assert.ok(result.errors.some(e=>e.includes('单词卡音频与完整词不符 am')));
});

test('removing a redundant canonical reference cannot silently authorize an untaught surface',t=>{
 const {source,current}=explicitBeFixture(t);
 current.lesson.requiredTaughtWords=[];delete current.lesson.teachingScope;current.save();
 let result=auditContentPackage(current.dir,{sourceLessons:[source.lesson]});
 assert.equal(result.contentValid,false);assert.ok(result.errors.some(e=>e.includes('词形缺少首教、原前置或本课显式教学证据 am')));
 const prerequisite=surfaceFixture(t,'N26-U003-L04','be','am');
 result=auditContentPackage(current.dir,{sourceLessons:[source.lesson,prerequisite.lesson]});
 assert.deepEqual(result.errors,[]);assert.equal(result.playable,false);
});

test('a later valid triplet cannot retrospectively authorize premature exposure to a new form',t=>{
 const {source,current}=explicitBeFixture(t),l=current.lesson;
 l.steps.splice(1,0,{...l.steps[2],id:l.courseId+'-premature'});
 l.sixStages=[1,2,3,4,5,6].map(id=>({id,steps:l.steps.filter(s=>s.stage===id).map(s=>s.id)}));
 current.save();
 const result=auditContentPackage(current.dir,{sourceLessons:[source.lesson]});
 assert.equal(result.contentValid,false);assert.ok(result.errors.some(e=>e.includes('显式词形或义项缺少')));
});

test('registered surfaces and complete teaching sequences cannot counterfeit a canonical word key',t=>{
 const {source,current}=explicitBeFixture(t),l=current.lesson;
 l.teachingScope.introduced[0].surface='helicopter';l.actualWords[0].word='helicopter';
 for(const step of l.steps)if(step.display)step.display='helicopter';
 l.checks[0].answers=['helicopter'];current.pkg.audio.find(a=>a.id==='apple').text='helicopter';current.save();
 let result=auditContentPackage(current.dir,{sourceLessons:[source.lesson]});
 assert.equal(result.contentValid,false);assert.ok(result.errors.some(e=>e.includes('规范词key不符')));
 const fake=surfaceFixture(t,'N26-U034-L02','t-shirt','t-shirt-shirt');
 result=auditContentPackage(fake.dir);
 assert.equal(result.contentValid,false);assert.ok(result.errors.some(e=>e.includes('规范词key不符')));
});

test('whole hyphenated answers and help-only English media remain inside the actual vocabulary',t=>{
 const f=surfaceFixture(t,'N26-U034-L02','t-shirt','t-shirt');
 f.lesson.checks[0].answers=['tshirt'];f.save();
 let result=auditContentPackage(f.dir);
 assert.equal(result.contentValid,false);assert.ok(result.errors.some(e=>e.includes('尚未示范 tshirt')));
 f.lesson.checks[0].answers=['t-shirt'];
 const step=f.lesson.steps[2].id;
 f.lesson.helpBranches=[{id:'help',forStep:step,retry:{sameStep:step,supported:true,independentEligible:false},audio:'help-only',onRepeatedDifficulty:{awardMastery:false}}];
 f.pkg.audio.push({id:'help-only',language:'en',text:'helicopter',asset:null});f.save();
 result=auditContentPackage(f.dir);
 assert.equal(result.contentValid,false);assert.ok(result.errors.some(e=>e.includes('漏列 helicopter')));
});

test('reviewed match/matches requires explicit teaching and does not open arbitrary es forms',t=>{
 const f=surfaceFixture(t,'N26-U035-L02','match','matches'),l=f.lesson;
 assert.equal(auditContentPackage(f.dir).contentValid,false);
 l.teachingScope={introduced:[{key:'match',surface:'matches',meaning:'相配，配合单件衣物时的形式',kind:'explicit_form_or_sense'}]};
 l.steps.splice(1,0,{id:l.courseId+'-meaning',course:l.courseId,stage:2,phase:'释义',display:'matches',instruction:'相配，配合单件衣物时的形式。',audio:'meaning',avatar:{phase:'meaning'}});
 f.pkg.audio.push({id:'meaning',language:'zh',text:'相配，配合单件衣物时的形式。',asset:null});
 l.sixStages=[1,2,3,4,5,6].map(id=>({id,steps:l.steps.filter(s=>s.stage===id).map(s=>s.id)}));f.save();
 assert.deepEqual(auditContentPackage(f.dir).errors,[]);
 l.teachingScope.introduced[0].surface='matcheses';l.actualWords[0].word='matcheses';
 for(const s of l.steps)if(s.display)s.display='matcheses';l.checks[0].answers=['matcheses'];f.pkg.audio.find(a=>a.id==='apple').text='matcheses';f.save();
 const result=auditContentPackage(f.dir);assert.equal(result.contentValid,false);assert.ok(result.errors.some(e=>e.includes('规范词key不符')));
});
