import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import crypto from 'node:crypto';
import http from 'node:http';
import {AdminStore,unionMs} from '../services/admin-store.mjs';
import {AuthStore} from '../services/auth-http.mjs';
import {createAdminHttp} from '../services/admin-http.mjs';
import {fetchBill} from '../services/tencent-billing.mjs';
const catalog={release:'test',courses:[{id:'course-v1',status:'published',stages:[]}],lexicon:[]};
function fixture(t){const dir=fs.mkdtempSync(path.join(os.tmpdir(),'snow-admin-')),now=Date.parse('2026-10-31T01:00:00Z'),store=new AdminStore({directory:path.join(dir,'admin'),now:()=>now}),auth=new AuthStore({directory:path.join(dir,'auth'),now:()=>now});t.after(()=>{store.close();auth.close();fs.rmSync(dir,{recursive:true,force:true});});return {store,auth,now};}
test('union and midnight attribution deduplicate simultaneous devices and retry',t=>{
 const {store,now}=fixture(t);assert.equal(unionMs([[0,10],[5,20],[30,40]]),30);
 const start=Date.parse('2026-10-30T15:59:50Z');
 const intervals=[{id:'a',session:'one',start,end:start+20000,active:true,course:'course-v1'},{id:'b',session:'two',start,end:start+20000,active:true,course:'course-v1'}];
 store.ingest('u',{intervals,events:[]},catalog);store.ingest('u',{intervals,events:[]},catalog);
 const daily=store.daily('2026-10-30','2026-10-31');assert.equal(daily.length,2);assert.equal(daily.reduce((n,r)=>n+r.learningMs,0),20000);
 store.ingest('u',{intervals:[{...intervals[0],id:'invalid',start:now-999999,end:now}],events:[]},catalog);assert.equal(store.db.prepare('SELECT count(*) n FROM activity').get().n,2);
});
test('admin authentication, CSRF, account isolation, checkpoints, revocation and official billing',async t=>{
 const {store,auth}=fixture(t);const salt=crypto.randomBytes(16).toString('hex'),password=crypto.randomBytes(12).toString('hex');store.db.prepare('INSERT OR REPLACE INTO admins VALUES(?,?,?)').run('admin',salt,crypto.scryptSync(password,salt,64).toString('hex'));
 const row={id:'learner',nickname:'验收用户',phone_key:'test',phone_cipher:auth.encrypt('+8613800000000')};auth.db.prepare('INSERT INTO users VALUES(?,?,?,?,?)').run(row.id,row.phone_key,row.phone_cipher,row.nickname,1);const learner=auth.createSession(row);
 const handler=createAdminHttp(store,auth,{secure:false,catalog,billing:async month=>({month,summary:{SummaryOverview:[{BusinessCodeName:'语音合成',RealTotalCost:'1.23'}]},details:[]})});
 const server=http.createServer((req,res)=>handler(req,res,new URL(req.url,'http://localhost')));await new Promise(r=>server.listen(0,'127.0.0.1',r));t.after(()=>server.close());const origin=`http://127.0.0.1:${server.address().port}`;
 const request=(route,{body,cookie='',cross=false}={})=>fetch(origin+route,{method:body?'POST':'GET',headers:{cookie,...(body?{'Content-Type':'application/json',Origin:cross?'http://evil.test':origin}:{})},...(body?{body:JSON.stringify(body)}:{})});
 assert.equal((await request('/api/admin/users')).status,401);
 assert.equal((await request('/api/admin/login',{body:{username:'admin',password},cross:true})).status,403);
 const login=await request('/api/admin/login',{body:{username:'admin',password}});assert.equal(login.status,200);assert.match(login.headers.get('set-cookie'),/HttpOnly/);const cookie=login.headers.get('set-cookie').split(';')[0];
 assert.equal((await request('/api/admin/users',{cookie})).status,200);
 const lc=`scene_session=${learner.token}`;
 let r=await request('/api/auth/learning/batch',{cookie:lc,body:{userId:'someone-else',intervals:[],events:[{id:'event',at:store.now(),course:'course-v1',stage:'one',type:'start'}]}});assert.equal(r.status,200);assert.equal(store.db.prepare('SELECT user_id FROM events').get().user_id,row.id);
 const payload={checkpoint:{courseId:'course-v1',version:1,index:0}};
 assert.equal((await request('/api/auth/learning/state',{cookie:lc,body:{course:'course-v1',revision:0,payload}})).status,200);
 assert.equal((await request('/api/auth/learning/state',{cookie:lc,body:{course:'course-v1',revision:0,payload}})).status,409);
 r=await request('/api/admin/billing?month=2026-10',{cookie,body:{}});assert.equal(r.status,200);assert.equal((await r.json()).data.summary.SummaryOverview[0].RealTotalCost,'1.23');
 assert.equal((await request('/api/admin/users/learner',{cookie,body:{action:'disable'}})).status,200);assert.equal(auth.current(learner.token),null);assert.throws(()=>auth.createSession(row),/停用/);
 assert.equal((await request('/api/auth/learning/state',{cookie:lc})).status,401);
 await request('/api/admin/logout',{cookie,body:{}});assert.equal((await request('/api/admin/me',{cookie})).status,401);
});
test('billing pagination keeps official values without recomputing usage prices',async()=>{
 const calls=[];const data=await fetchBill('2026-10',async(action,payload)=>{calls.push({action,payload});if(action==='DescribeBillSummaryByProduct')return {SummaryOverview:[]};return {DetailSet:payload.Offset===0?Array.from({length:100},(_,i)=>({Id:i})): [{Id:100}],Context:'next'};});assert.equal(data.details.length,101);assert.equal(calls[2].payload.Offset,100);
});
