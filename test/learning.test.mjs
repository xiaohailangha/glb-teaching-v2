import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import crypto from 'node:crypto';
import http from 'node:http';
import {LearningStore,unionMs} from '../services/learning-store.mjs';
import {AuthStore} from '../services/auth-http.mjs';
import {createLearningHttp} from '../services/learning-http.mjs';
import {CloudCurriculum} from '../services/cloud-curriculum.mjs';
const catalog={release:'test',courses:[{id:'course-v1',status:'published',stages:[]}],lexicon:[]};
function fixture(t){const dir=fs.mkdtempSync(path.join(os.tmpdir(),'snow-admin-')),now=Date.parse('2026-10-31T01:00:00Z'),store=new LearningStore({directory:path.join(dir,'admin'),now:()=>now}),auth=new AuthStore({directory:path.join(dir,'auth'),now:()=>now});t.after(()=>{store.close();auth.close();fs.rmSync(dir,{recursive:true,force:true});});return {store,auth,now};}
test('learning time adds simultaneous devices, splits midnight and ignores upload retries',t=>{
 const {store,now}=fixture(t);assert.equal(unionMs([[0,10],[5,20],[30,40]]),30);
 const start=Date.parse('2026-10-30T15:59:50Z');
 const intervals=[{id:'a',session:'one',start,end:start+20000,active:true,course:'course-v1'},{id:'b',session:'two',start,end:start+20000,active:true,course:'course-v1'}];
 store.ingest('u',{intervals,events:[]},catalog);store.ingest('u',{intervals,events:[]},catalog);
 const daily=store.daily('2026-10-30','2026-10-31');assert.equal(daily.length,2);assert.equal(daily.reduce((n,r)=>n+r.learningMs,0),40000);
 store.ingest('u',{intervals:[{...intervals[0],id:'invalid',start:now-999999,end:now}],events:[]},catalog);assert.equal(store.db.prepare('SELECT count(*) n FROM activity').get().n,2);
});
test('APP learning runs independently with protected management contract',async t=>{
 const {store,auth}=fixture(t); const row={id:'learner',nickname:'验收用户',phone_key:'test',phone_cipher:auth.encrypt('+8613800000000')};auth.db.prepare('INSERT INTO users VALUES(?,?,?,?,?)').run(row.id,row.phone_key,row.phone_cipher,row.nickname,1);const learner=auth.createSession(row);
 const bridgeToken=crypto.randomBytes(32).toString('hex');
 const handler=createLearningHttp(store,auth,{secure:false,catalog,bridgeToken});
 const server=http.createServer((req,res)=>handler(req,res,new URL(req.url,'http://localhost')));await new Promise(r=>server.listen(0,'127.0.0.1',r));t.after(()=>server.close());const origin=`http://127.0.0.1:${server.address().port}`;
 const request=(route,{body,cookie='',cross=false}={})=>fetch(origin+route,{method:body?'POST':'GET',headers:{cookie,...(cookie==='bridge'?{Authorization:'Bearer '+bridgeToken}:{}),...(body?{'Content-Type':'application/json',Origin:cross?'http://evil.test':origin}:{})},...(body?{body:JSON.stringify(body)}:{})});
 assert.equal((await request('/internal/management/v1/users')).status,403);
 const cookie='bridge';
 assert.equal((await request('/internal/management/v1/users',{cookie})).status,200);
 const lc=`scene_session=${learner.token}`;
 assert.equal((await request('/api/auth/learning/curriculum')).status,401);
 const curriculum=await (await request('/api/auth/learning/curriculum',{cookie:lc})).json();
 assert.equal((await request('/api/auth/learning/pilot/catalog')).status,401);
 const trialCatalog=await (await request('/api/auth/learning/pilot/catalog',{cookie:lc})).json();assert.equal(trialCatalog.courses.length,2);
 assert.equal((await request('/api/auth/learning/pilot/course?course=N26-U084-L01',{cookie:lc})).status,200);
 assert.equal((await request('/api/auth/learning/pilot/course?course=N26-U001-L01',{cookie:lc})).status,404);
 assert.equal(curriculum.units.length,87);
 assert.equal((await request('/api/auth/learning/curriculum/start',{cookie:lc,cross:true,body:{level:1,revision:0}})).status,403);
 const start=await (await request('/api/auth/learning/curriculum/start',{cookie:lc,body:{level:1,revision:0,version:curriculum.version,user:'someone-else'}})).json();assert.equal(start.level,1);assert.deepEqual(start.progress,[]);
 const phoneme=await request('/api/auth/learning/curriculum/phoneme?course='+curriculum.courses[0].id+'&symbol=%C3%A6',{cookie:lc});assert.equal(phoneme.status,200);const reference=await phoneme.json();assert.equal(reference.asset.symbol,'æ');assert.equal(reference.asset.kind,'phonetic-reference');assert.equal(reference.course,curriculum.courses[0].id);
 const afterReference=await (await request('/api/auth/learning/curriculum/state',{cookie:lc})).json();assert.deepEqual(afterReference.progress,[]);assert.equal(afterReference.evidence.learnedWords,0);
 assert.equal((await request('/internal/management/v1/curriculum/review',{cookie:lc,body:{}})).status,403);
 assert.equal((await request('/internal/management/v1/curriculum',{cookie})).status,200);
 const readBack=await (await request('/internal/management/v1/curriculum/learner?user=learner',{cookie})).json();assert.equal(readBack.state.level,1);
 const formalCourse=curriculum.courses[0].id;
 let r=await request('/api/auth/learning/batch',{cookie:lc,body:{epoch:'formal555-reset-v2',userId:'someone-else',intervals:[],events:[{id:'event',at:store.now(),course:formalCourse,stage:'one',type:'start'}]}});assert.equal(r.status,200);assert.equal(store.db.prepare('SELECT user_id FROM events').get().user_id,row.id);
 assert.equal((await request('/api/auth/learning/summary')).status,401);
 const summary=await (await request('/api/auth/learning/summary?user=someone-else',{cookie:lc})).json();assert.equal(summary.courses,0);
 const lesson=new CloudCurriculum(store).lesson(formalCourse,curriculum.version).lesson,step=lesson.steps[0];
 const progressBody={course:formalCourse,step:step.id,revision:0,version:curriculum.version};
 assert.equal((await request('/api/auth/learning/curriculum/progress',{cookie:lc,body:progressBody})).status,409);
 assert.equal((await request('/api/auth/learning/curriculum/heard',{cookie:lc,body:{...progressBody,audio:step.audio}})).status,200);
 assert.equal((await request('/api/auth/learning/curriculum/progress',{cookie:lc,body:progressBody})).status,200);
 const explored=await (await request('/api/auth/learning/summary',{cookie:lc})).json();
 assert.equal(explored.chapters,1);assert.equal(explored.courses,1);assert.equal(explored.completedCourses,0);assert.equal(explored.confirmedWords,0);
 assert.equal((await request('/api/auth/learning/curriculum/progress',{cookie:lc,body:progressBody})).status,409);
 const state=await (await request('/api/auth/learning/curriculum/state',{cookie:lc})).json();
 assert.equal(state.progress[0].pendingStep,lesson.steps[1].id);
 assert.deepEqual(state.progress[0].visitedSteps,[step.id]);
 assert.equal(state.progress[0].completed,false);
 assert.deepEqual(new CloudCurriculum(store).state('someone-else').progress,[]);
 assert.equal((await request('/internal/management/v1/users/learner',{cookie,body:{action:'disable'}})).status,200);assert.equal(auth.current(learner.token),null);assert.throws(()=>auth.createSession(row),/停用/);
 assert.equal((await request('/api/auth/learning/state',{cookie:lc})).status,401);
 assert.equal(store.db.prepare("SELECT count(*) n FROM sqlite_master WHERE name='admins'").get().n,0);
});

test('personal summary deduplicates content, sums device time and isolates accounts',t=>{
 const {store,now}=fixture(t);
 const cat={courses:[{id:'course-v1',status:'published',stages:[{id:'a',chapter:'第一章'},{id:'b',chapter:'第一章'},{id:'c',chapter:'第二章'}]}]};
 const e=(id,type,stage='a',detail={})=>({id,type,stage,detail,course:'course-v1',at:now});
 const intervals=[{id:'i1',session:'s1',start:now-15000,end:now,active:true,course:'course-v1'},{id:'i2',session:'s2',start:now-15000,end:now,active:true,course:'course-v1'}];
 store.ingest('one',{intervals,events:[e('s','start'),e('a','stage'),e('b','stage','b'),e('c','stage','c'),e('f','finish'),e('f2','finish'),e('w','expose','a',{words:['apple','apples','banana']})]},cat);
 store.ingest('two',{intervals:[],events:[e('other','expose','a',{words:['orange']})]},cat);
 const r=store.summary('one',cat);
 assert.equal(r.chapters,2);assert.equal(r.courses,1);assert.equal(r.completedCourses,1);assert.equal(r.words,2);assert.equal(r.learningMs,30000);assert.equal(r.learningDays,1);assert.equal(r.trend.length,7);assert.equal(r.averageDailyHours,30000/7/3600000);
 const empty=store.summary('new',cat);assert.equal(empty.words,0);assert.equal(empty.chapters,0);assert.equal(empty.averageDailyHours,0);
});

test('relearning accumulates across sessions and accounts retain history',t=>{
 const {store,now}=fixture(t);
 const row=(id,session,start,end)=>({id,session,start,end,active:true,course:'course-v1'});
 const intervals=[row('first','device-a',now-40000,now-20000),row('again','device-a',now-20000,now),row('other-device','device-b',now-20000,now)];
 store.ingest('owner',{intervals,events:[]},catalog);
 store.ingest('owner',{intervals,events:[]},catalog);
 assert.equal(store.summary('owner',catalog).learningMs,60000);
 assert.equal(store.summary('another-account',catalog).learningMs,0);
});

test('personal study duration includes historical idle app intervals',t=>{
 const {store,now}=fixture(t);
 store.ingest('owner',{events:[],intervals:[{id:'idle',session:'s',start:now-10000,end:now,active:false,course:''}]},catalog);
 assert.equal(store.summary('owner',catalog).learningMs,10000);
 assert.equal(store.summary('owner',catalog).learningDays,1);
});
