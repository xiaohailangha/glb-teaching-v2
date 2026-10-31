import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
const origin = 'https://49.233.179.83';
const password = process.env.ADMIN_TEST_PASSWORD;
if (!password) throw Error('Set ADMIN_TEST_PASSWORD for the authorized administrator.');
const checks = [];
const request = (path, options = {}) => fetch(origin + path, {signal: AbortSignal.timeout(30000), ...options});
async function check(name, task) { await task(); checks.push(name); console.log('PASS ' + name); }
await check('anonymous admin and learning requests are rejected', async () => {
  for (const route of ['/api/admin/overview', '/api/auth/learning/state']) assert.equal((await request(route)).status, 401);
});
await check('cross-origin admin login is rejected', async () => {
  assert.equal((await request('/api/admin/login', {method:'POST',headers:{Origin:'https://example.org','Content-Type':'application/json'},body:'{}'})).status,403);
});
const response = await request('/api/admin/login', {method:'POST',headers:{Origin:origin,'Content-Type':'application/json'},body:JSON.stringify({username:'admin',password})});
assert.equal(response.status,200);
const cookie = response.headers.get('set-cookie');
assert.match(cookie,/HttpOnly/); assert.match(cookie,/Secure/); assert.match(cookie,/SameSite=Strict/);
const headers = {Cookie:cookie.split(';')[0],Origin:origin,'Content-Type':'application/json'};
const get = async route => { const r=await request('/api/admin/'+route,{headers}); assert.equal(r.status,200); return r.json(); };
await check('real course catalog and assets are available', async () => {
  const catalog = await get('catalog');
  assert.equal(catalog.courses.filter(c=>c.status==='published').length,8);
  assert.equal(catalog.courses.length,16);
  const paths=[...new Set(JSON.stringify(catalog).match(/\/scene\/assets\/[^"\s]+/g))];
  assert.ok(paths.length>20);
  for(let i=0;i<paths.length;i+=8) await Promise.all(paths.slice(i,i+8).map(async path=>assert.equal((await request(path,{method:'HEAD'})).status,200,path)));
});
await check('all operational read endpoints return real data', async () => {
  for (const route of ['overview','users','daily','events','logs','system']) {
    const data=await get(route); assert.equal(data.error,undefined);
    if(route==='system'){assert.ok(data.backup); assert.equal(data.backupError,null);}
  }
});
await check('official Tencent billing snapshot is connected', async () => {
  const bill=await get('billing'); assert.ok(bill.updated); assert.equal(bill.error,null);
  assert.equal(bill.data.source,'腾讯云官方账单'); assert.ok(bill.data.summary); assert.ok(Array.isArray(bill.data.details));
});
await check('original website and classroom remain accessible', async () => {
  assert.equal(await(await request('/')).text(),await fs.readFile('build/web/index.html','utf8'));
  assert.match(await(await request('/scene/')).text(),/<base href="\/scene\/">/);
  assert.match(await(await request('/admin/')).text(),/Snow Speaks/);
});
await check('private data cannot be downloaded', async () => {
  for(const path of ['/work/admin-private/management.sqlite','/.secrets/admin-bootstrap.json','/admin/data/catalog.json']) assert.ok([403,404].includes((await request(path)).status));
});
await check('logout invalidates the admin session', async () => {
  assert.equal((await request('/api/admin/logout',{method:'POST',headers,body:'{}'})).status,200);
  assert.equal((await request('/api/admin/me',{headers})).status,401);
});
await fs.writeFile('docs/admin/live-verification.json',JSON.stringify({checkedAt:new Date().toISOString(),origin,checks,syntheticProductionLearnersCreated:false,realSmsSent:false},null,2)+'\n');
