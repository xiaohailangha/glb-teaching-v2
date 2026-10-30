import test from 'node:test';
import assert from 'node:assert/strict';
import {FrameMeter} from '../assets/avatar/performance.js';

function meter(){
  const events={};
  globalThis.document={hidden:false,visibilityState:'visible',createElement:()=>({}),body:{append(){}},addEventListener:(name,fn)=>{events[name]=fn;}};
  globalThis.location={search:''};globalThis.innerWidth=704;globalThis.innerHeight=900;globalThis.devicePixelRatio=1;
  const result=new FrameMeter();result.gpu=[];return {result,events};
}
test('frame meter reports delivered 20 FPS instead of clamping it to the target',()=>{
  const {result}=meter();
  for(let i=0;i<=120;i++){result.begin(i*50);result.end();}
  assert.equal(result.summarize().fps,20);assert.equal(result.summarize().frameP95,50);
});
test('30-second benchmark uses full delivered intervals and ignores initial warmup',()=>{
  const {result}=meter();
  result.run={mode:'speech',start:2000,duration:30000,first:0,samples:[],invalid:false};
  for(let i=0;i<=1922;i++){result.begin(i*1000/60);result.end();}
  assert.ok(result.result);assert.ok(Math.abs(result.result.fps-60)<.05);
  assert.ok(result.result.durationMs>=30000);assert.equal(result.result.valid,true);
});
test('switching to the background invalidates an in-progress benchmark',()=>{
  const {result,events}=meter();
  result.run={mode:'idle',start:2000,duration:30000,first:0,samples:[],invalid:false};
  document.hidden=true;events.visibilitychange();assert.equal(result.run.invalid,true);
  document.hidden=false;events.visibilitychange();
  for(let i=40;i<=642;i++){result.begin(i*50);result.end();}
  assert.equal(result.result.valid,false);
});
