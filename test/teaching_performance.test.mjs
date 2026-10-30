import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {applyPerformanceFace,clearPerformanceFace,curve,applyIdleFace} from '../assets/avatar/teaching-performance.js';
import {NaturalMotion,makeTimeline} from '../assets/avatar/motion.js';

test('ten-second acting stays finite and continuous while lips articulate',()=>{
 const audio=JSON.parse(fs.readFileSync(new URL('../assets/avatar/audio/performance-cues.json',import.meta.url)));
 const timeline=makeTimeline(audio.cues);const motion=new NaturalMotion(()=>.5);
 let previous=null;const phases=new Set();
 for(let i=0;i<=2400;i++){
  const t=i/240;motion.update(1/240,{timeline,time:t,speaking:true,session:1});
  phases.add(applyPerformanceFace(motion.weights,t));
  for(const [name,value]of Object.entries(motion.weights))assert.ok(Number.isFinite(value)&&value>=0&&value<=1,name);
  if(previous)for(const name of ['GazeRight','Warm','Curious','SmileLeft'])assert.ok(Math.abs(motion.weights[name]-previous[name])<.08,name);
  previous={...motion.weights};
 }
 assert.equal(phases.size,5);
 clearPerformanceFace(motion.weights);assert.equal(motion.weights.GazeRight,0);assert.equal(motion.weights.SmileLeft,0);
});

test('performance has full ten-second audio, distinct eye shifts and asymmetric expression',()=>{
 const wav=fs.readFileSync(new URL('../assets/avatar/audio/performance.wav',import.meta.url));
 // Traverse RIFF chunks rather than assuming a fixed 44-byte WAV header.
 let offset=12,rate=0,bytes=0;
 while(offset+8<=wav.length){const name=wav.toString('ascii',offset,offset+4),size=wav.readUInt32LE(offset+4);if(name==='fmt ')rate=wav.readUInt32LE(offset+16);if(name==='data')bytes=size;offset+=8+size+(size%2);}
 assert.equal(bytes/rate,10);
 const w={AA:.6};applyPerformanceFace(w,2.1);assert.ok(w.GazeRight>.6);assert.notEqual(w.BrowLeft,w.BrowRight);assert.ok(w.SmileLeft>0,'emotion remains during speech');
 assert.equal(curve([[0,0],[1,1]],.5),.5);
});

test('facial acting preserves cheek/eye emotion during articulation and restores a friendly idle',()=>{
 const silent={AA:0,OO:0,UU:0,MBP:0},speaking={AA:.7,OO:0,UU:0,MBP:0};
 applyPerformanceFace(silent,1.3);applyPerformanceFace(speaking,1.3);
 assert.ok(silent.SmileLeft>.9);
 assert.ok(silent.SmileEyes>.8);
 assert.equal(speaking.SmileEyes,silent.SmileEyes,'eye expression is independent from phonemes');
 assert.ok(speaking.SmileLeft>0&&speaking.SmileLeft<silent.SmileLeft);
 const wideVowel={EE:.75};applyPerformanceFace(wideVowel,1.3);
 assert.ok(wideVowel.SmileLeft<silent.SmileLeft*.6,'wide vowels do not double the smiling lip deformation');
 assert.equal(wideVowel.SmileEyes,silent.SmileEyes);
 const invitation={};applyPerformanceFace(invitation,6.8);
 assert.ok(invitation.Curious>silent.Curious+.3);
 assert.ok(invitation.BrowLeft>invitation.BrowRight);
 clearPerformanceFace(silent);applyIdleFace(silent);
 assert.ok(silent.SmileLeft>.3&&silent.SmileEyes>.2);
});

test('runtime asset contains one 10-second skeletal clip and normalized skin weights',()=>{
 const data=fs.readFileSync(new URL('../assets/avatar/models/storm-performance.glb',import.meta.url));
 const size=data.readUInt32LE(12),doc=JSON.parse(data.toString('utf8',20,20+size));
 const bin=20+size+8;
 const accessor=index=>{const a=doc.accessors[index],v=doc.bufferViews[a.bufferView];return {a,start:bin+(v.byteOffset||0)+(a.byteOffset||0)};};
 assert.equal(doc.animations.length,2);assert.equal(doc.animations[0].name,'Teaching_Apple_10s');
 assert.ok(doc.skins.length>0);assert.equal(doc.skins[0].joints.length,128);
 let end=0;
 for(const s of doc.animations[0].samplers){const {a,start}=accessor(s.input);end=Math.max(end,data.readFloatLE(start+(a.count-1)*4));}
 assert.equal(end,10);
 for(const m of doc.meshes)for(const p of m.primitives){
  assert.ok(p.attributes.JOINTS_0!==undefined);
  const {a,start}=accessor(p.attributes.WEIGHTS_0);assert.equal(a.componentType,5126);
  for(let i=0;i<a.count;i++){let sum=0;for(let j=0;j<4;j++)sum+=data.readFloatLE(start+(i*4+j)*4);assert.ok(Math.abs(sum-1)<.0001);}
 }
});
