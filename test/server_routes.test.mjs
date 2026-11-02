import test from 'node:test';
import assert from 'node:assert/strict';
import {spawn} from 'node:child_process';
import {once} from 'node:events';

test('server exposes the current application and retires experimental routes',async t=>{
  const child=spawn(process.execPath,['server.mjs'],{env:{...process.env,PORT:'0'},stdio:['ignore','pipe','pipe']});
  t.after(async()=>{if(child.exitCode===null){const exited=once(child,'exit');child.kill();await exited;}});
  const origin=await new Promise((resolve,reject)=>{
    let output='';
    const timer=setTimeout(()=>reject(Error('Server startup timed out')),10000);
    child.once('error',error=>{clearTimeout(timer);reject(error);});
    child.once('exit',code=>{clearTimeout(timer);reject(Error(`Server exited: ${code}`));});
    child.stdout.on('data',chunk=>{
      output+=chunk;
      const match=output.match(/http:\/\/127\.0\.0\.1:\d+/);
      if(match){clearTimeout(timer);resolve(match[0]);}
    });
  });
  const request=(path,options={})=>fetch(origin+path,{...options,redirect:'manual',signal:AbortSignal.timeout(5000)});
  const entry=await request('/');
  assert.equal(entry.status,302);
  assert.equal(entry.headers.get('location'),'/scene/');
  assert.equal((await request('/health')).status,200);
  for(const path of ['/avatar-dev/index.html','/benchmark','/performance-recording']) {
    assert.equal((await request(path)).status,404,path);
    assert.equal((await request(path,{method:'POST'})).status,404,path);
  }
  for(const path of ['/server.mjs','/.secrets/tencent.json','/scene/../server.mjs']) {
    assert.equal((await request(path)).status,404,path);
  }
});
