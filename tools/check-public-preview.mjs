import fs from 'node:fs';
import assert from 'node:assert/strict';
const origin=fs.readFileSync(new URL('../work/tunnel/public-origin.txt',import.meta.url),'utf8').trim();
const {token}=JSON.parse(fs.readFileSync(new URL('../work/tunnel/session.json',import.meta.url),'utf8'));
const request=(path,options={})=>fetch(origin+path,{...options,signal:AbortSignal.timeout(12000)});
try {
  const gate=await request('/enter?key='+token,{redirect:'manual'});
  assert.equal(gate.status,303,'Public tunnel does not reach the authenticated gateway');
  const cookie=gate.headers.get('set-cookie');
  assert.match(cookie,/__Host-glb_preview=/);
  const headers={cookie:cookie.split(';')[0]};
  const status=await request('/api/speech/status?check='+Date.now(),{headers});
  assert.equal(status.status,200);
  const data=await status.json();assert.equal(data.configured,true);
  console.log('Public gateway and speech backend reachable.');
}catch(error){console.error('Public preview is unavailable: '+error.message);process.exitCode=1;}
