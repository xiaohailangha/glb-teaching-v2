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
const catalog={release:'test',courses:[{id:'course-v1',status:'published',stages:[]}],lexicon:[]};
function fixture(t){const dir=fs.mkdtempSync(path.join(os.tmpdir(),'snow-admin-')),now=Date.parse('2026-10-31T01:00:00Z'),store=new LearningStore({directory:path.join(dir,'admin'),now:()=>now}),auth=new AuthStore({directory:path.join(dir,'auth'),now:()=>now});t.after(()=>{store.close();auth.close();fs.rmSync(dir,{recursive:true,force:true});});return {store,auth,now};}
test('union and midnight attribution deduplicate simultaneous devices and retry',t=>{
 const {store,now}=fixture(t);assert.equal(unionMs([[0,10],[5,20],[30,40]]),30);
 const start=Date.parse('2026-10-30T15:59:50Z');
 const intervals=[{id:'a',session:'one',start,end:start+20000,active:true,course:'course-v1'},{id:'b',session:'two',start,end:start+20000,active:true,course:'course-v1'}];
 store.ingest('u',{intervals,events:[]},catalog);store.ingest('u',{intervals,events:[]},catalog);
 const daily=store.daily('2026-10-30','2026-10-31');assert.equal(daily.length,2);assert.equal(daily.reduce((n,r)=>n+r.learningMs,0),20000);
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
 let r=await request('/api/auth/learning/batch',{cookie:lc,body:{userId:'someone-else',intervals:[],events:[{id:'event',at:store.now(),course:'course-v1',stage:'one',type:'start'}]}});assert.equal(r.status,200);assert.equal(store.db.prepare('SELECT user_id FROM events').get().user_id,row.id);
 const payload={checkpoint:{courseId:'course-v1',version:1,index:0}};
 assert.equal((await request('/api/auth/learning/state',{cookie:lc,body:{course:'course-v1',revision:0,payload}})).status,200);
 assert.equal((await request('/api/auth/learning/state',{cookie:lc,body:{course:'course-v1',revision:0,payload}})).status,409);
 assert.equal((await request('/internal/management/v1/users/learner',{cookie,body:{action:'disable'}})).status,200);assert.equal(auth.current(learner.token),null);assert.throws(()=>auth.createSession(row),/停用/);
 assert.equal((await request('/api/auth/learning/state',{cookie:lc})).status,401);
 assert.equal(store.db.prepare("SELECT count(*) n FROM sqlite_master WHERE name='admins'").get().n,0);
});
