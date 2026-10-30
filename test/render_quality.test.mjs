import test from 'node:test';
import assert from 'node:assert/strict';
import {RenderQuality,cadenceFromIntervals} from '../assets/avatar/render-quality.js';

test('browser cadence probe distinguishes 60/90/120 callbacks despite loading outliers',()=>{
  for(const hz of [60,90,120])assert.equal(cadenceFromIntervals([...Array(45).fill(1000/hz),80,100,50]),hz);
});
test('high profile renders every available 90/120 frame and lower profiles pace actual delivered frames',()=>{
  for(const hz of [60,90,120])for(const preset of ['high','medium','low']){
    const q=new RenderQuality({cadence:hz});q.configure({quality:preset,adaptive:false});let frames=0;
    for(let i=0;i<hz*10;i++)if(q.shouldRender(i*1000/hz))frames++;
    assert.ok(Math.abs(frames/10-q.targetFps)<.2,`${hz}/${preset}: ${frames/10}`);
    if(preset==='high')assert.equal(q.targetFps,hz);
  }
});
test('sustained overload lowers resolution before cadence and recovery uses hysteresis',()=>{
  const q=new RenderQuality({cadence:120,pixelRatio:2});
  let t=0;for(;t<45000;t+=16.7)q.observe(t,16.7,10);
  assert.equal(q.ratio,q.minRatio);assert.equal(q.targetFps,60);
  for(let end=t+5000;t<end;t+=16.7)q.observe(t,16.7,2);
  assert.equal(q.targetFps,60,'brief recovery must not flap');
  for(let end=t+16000;t<end;t+=1000/q.targetFps)q.observe(t,1000/q.targetFps,2);
  assert.equal(q.targetFps,120);
});
test('manual profile ignores overload; resume discards hidden-tab timing',()=>{
  const q=new RenderQuality({cadence:120,pixelRatio:2});q.configure({quality:'high',adaptive:false});
  for(let t=0;t<60000;t+=50)q.observe(t,50,40);
  assert.equal(q.ratio,1.5);assert.equal(q.targetFps,120);
  q.resetTiming();assert.equal(q.samples.length,0);assert.equal(q.next,0);
});
