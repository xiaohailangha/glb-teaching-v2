import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import http from 'node:http';
import {AuthStore,createAuthHttp} from '../services/auth-http.mjs';

function setup(t,options={}){
  const directory=fs.mkdtempSync(path.join(os.tmpdir(),'scene-auth-test-'));let sent=[],time=100000000;
  const store=new AuthStore({directory,configured:()=>true,send:async(phone,code)=>{sent.push({phone,code});},now:()=>time,...options});
  t.after(()=>{store.close();fs.rmSync(directory,{recursive:true,force:true});});
  return {store,sent,directory,tick:ms=>time+=ms};
}
test('SMS cannot claim sent when unconfigured or provider fails',async t=>{
  const a=setup(t,{configured:()=>false});await assert.rejects(a.store.requestCode('13800138000','ip'),e=>e.status===503);assert.equal(a.sent.length,0);
  const b=setup(t,{send:async()=>{throw Error('provider private error');}});await assert.rejects(b.store.requestCode('13800138000','ip'),/验证码未能发送/);
  assert.equal(b.store.db.prepare('SELECT count(*) AS n FROM challenges').get().n,0);
});
test('verified phone creates profile once, opaque sessions restore and logout revokes',async t=>{
  const {store,sent,tick}=setup(t);const phone='13800138000';
  const request=await store.requestCode(phone,'a');assert.equal('code' in request,false);
  const proof=store.verify({...request,code:sent[0].code},'a');assert.ok(proof.registrationToken);
  assert.throws(()=>store.verify({...request,code:sent[0].code},'a'),/失效/);
  const account=store.register(proof.registrationToken,' 莉莉 ');assert.equal(account.user.nickname,'莉莉');assert.equal(account.user.phoneMasked,'138****8000');
  assert.throws(()=>store.register(proof.registrationToken,'其他人'),/过期/);
  assert.deepEqual(store.current(account.token),account.user);
  assert.equal(store.rename(account.token,'小雨').nickname,'小雨');
  const row=store.db.prepare('SELECT * FROM users').get();assert.ok(!JSON.stringify(row).includes(phone));
  const challenge=store.db.prepare('SELECT * FROM challenges').get();assert.equal(challenge,undefined);
  tick(61000);const next=await store.requestCode(phone,'a');const login=store.verify({...next,code:sent[1].code},'a');
  assert.equal(login.user.id,account.user.id);assert.equal(login.user.nickname,'小雨');
  store.logout(login.token);assert.equal(store.current(login.token),null);
});
test('cooldown, expiry, failed guesses, phone and global limits persist',async t=>{
  const {store,sent,tick}=setup(t);const request=await store.requestCode('13800138000','a');
  await assert.rejects(store.requestCode('13800138000','a'),e=>e.status===429);
  const wrong=sent[0].code==='000000'?'111111':'000000';
  for(let i=0;i<5;i++)assert.throws(()=>store.verify({...request,code:wrong},'a'),/不正确/);
  assert.throws(()=>store.verify({...request,code:sent[0].code},'a'),/失效/);
  tick(61000);const second=await store.requestCode('13800138000','a');tick(301000);
  assert.throws(()=>store.verify({...second,code:sent[1].code},'a'),/失效/);
  await store.requestCode('13800138000','a');tick(61000);
  await assert.rejects(store.requestCode('13800138000','a'),e=>e.status===429);
});
test('concurrent sends do not bypass cooldown and pending delivery cannot verify',async t=>{
  let release;const wait=new Promise(r=>release=r);const {store}=setup(t,{send:()=>wait});
  const first=store.requestCode('13800138000','a');await assert.rejects(store.requestCode('13800138000','a'),e=>e.status===429);
  const row=store.db.prepare('SELECT * FROM challenges').get();assert.throws(()=>store.verify({challengeId:row.id,code:'000000'},'a'),/失效/);
  release();await first;
});
test('registration proof expires and invalid nickname cannot overwrite an account',async t=>{
  const {store,sent,tick}=setup(t);const request=await store.requestCode('13800138000','a');
  const proof=store.verify({...request,code:sent[0].code},'a');
  assert.throws(()=>store.register(proof.registrationToken,'<script>'),/昵称/);
  tick(301000);assert.throws(()=>store.register(proof.registrationToken,'莉莉'),/过期/);
  assert.throws(()=>store.rename('unknown','莉莉'),e=>e.status===401);
});
test('HTTP rejects cross-site requests, sets HttpOnly cookie, never returns session secret',async t=>{
  const {store,sent}=setup(t);const handler=createAuthHttp(store,{secure:false});
  const server=http.createServer((req,res)=>handler(req,res,new URL(req.url,'http://localhost')));
  await new Promise(r=>server.listen(0,'127.0.0.1',r));t.after(()=>new Promise(r=>server.close(r)));
  const origin=`http://127.0.0.1:${server.address().port}`;
  const post=(route,data,extra={})=>fetch(origin+'/api/auth/'+route,{method:'POST',headers:{Origin:origin,'Content-Type':'application/json',...extra},body:JSON.stringify(data)});
  assert.equal((await post('code',{phone:'13800138000'},{Origin:'https://evil.test'})).status,403);
  const r=await post('code',{phone:'13800138000'}),request=await r.json();
  const v=await post('verify',{...request,code:sent[0].code}),proof=await v.json();
  const created=await post('register',{...proof,nickname:'莉莉'}),data=await created.json();
  assert.equal(data.token,undefined);assert.equal(data.user.nickname,'莉莉');
  assert.match(created.headers.get('set-cookie'),/HttpOnly; SameSite=Lax/);
  const cookie=created.headers.get('set-cookie').split(';')[0];
  const me=await fetch(origin+'/api/auth/me',{headers:{Cookie:cookie}});assert.equal((await me.json()).user.nickname,'莉莉');
  await post('logout',{}, {Cookie:cookie});const after=await fetch(origin+'/api/auth/me',{headers:{Cookie:cookie}});assert.equal((await after.json()).user,null);
});
