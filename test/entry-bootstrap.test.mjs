import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
const source=fs.readFileSync('scene-preview/web/flutter_bootstrap.js','utf8').replace('{{flutter_js}}','').replace('{{flutter_build_config}}','');
for(const failure of [null,'load','engine','run'])test(`entry startup uses local renderer and handles ${failure??'success'}`,async()=>{
 let failed=0,ran=0,removed=[];
 const scope='https://example.test/scene/';
 const context={URL,document:{baseURI:scope},navigator:{serviceWorker:{getRegistrations:async()=>[
  {scope,unregister:async()=>removed.push(scope)},
  {scope:'https://example.test/admin/',unregister:async()=>removed.push('admin')},
 ]}},window:{sceneBootFailed:()=>failed++},_flutter:{loader:{load:async options=>{
  assert.equal(options.config.canvasKitBaseUrl,'canvaskit/');
  if(failure==='load')throw Error('network');
  await options.onEntrypointLoaded({initializeEngine:async config=>{
   assert.equal(config.canvasKitBaseUrl,'canvaskit/');
   if(failure==='engine')throw Error('engine');
   return {runApp:async()=>{if(failure==='run')throw Error('run');ran++;}};
  }});
 }}}};
 await vm.runInNewContext(source,context);
 assert.deepEqual(removed,[scope]);assert.equal(failed,failure?1:0);assert.equal(ran,failure?0:1);
});
