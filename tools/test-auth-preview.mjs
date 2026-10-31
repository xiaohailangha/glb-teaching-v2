import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
const origin='https://49.233.179.83';
const checks=[];
async function check(name,fn){await fn();checks.push(name);console.log('PASS '+name);}
const post=(route,data,headers={},method='POST')=>fetch(origin+'/api/auth/'+route,{method,headers:{Origin:origin,'Content-Type':'application/json',...headers},body:JSON.stringify(data)});
const status=await (await fetch(origin+'/api/auth/status')).json();
await check('auth status is explicit and no credentials are returned',async()=>{assert.equal(typeof status.smsReady,'boolean');assert.deepEqual(Object.keys(status),['smsReady']);});
await check('anonymous session is not authenticated',async()=>{const r=await fetch(origin+'/api/auth/me');assert.equal(r.status,200);assert.deepEqual(await r.json(),{user:null});});
await check('cross-site requests cannot send codes',async()=>{assert.equal((await post('code',{phone:'13800138000'},{Origin:'https://example.org'})).status,403);});
await check('nickname cannot change without a verified session',async()=>{const r=await post('me',{nickname:'莉莉'},{},'PATCH');assert.equal(r.status,401);});
await check('registration cannot bypass phone verification',async()=>{const r=await post('register',{nickname:'莉莉',registrationToken:'not-a-verified-token'});assert.equal(r.status,400);});
if(!status.smsReady)await check('unconfigured SMS never returns a fake code or success',async()=>{const r=await post('code',{phone:'13800138000'});assert.equal(r.status,503);const data=await r.json();assert.equal(data.challengeId,undefined);assert.equal(data.code,undefined);});
await check('account database and provider configuration cannot be downloaded',async()=>{for(const p of ['/work/auth-private/accounts.sqlite','/work/auth-private/encryption.key','/.secrets/tencent-sms.json','/scene/.secrets/tencent-sms.json']){const r=await fetch(origin+p);assert.ok([403,404].includes(r.status));await r.arrayBuffer();}});
await fs.writeFile('docs/auth/live-verification.json',JSON.stringify({checkedAt:new Date().toISOString(),smsReady:status.smsReady,realSmsSent:false,checks},null,2)+'\n');
