import test from 'node:test';
import assert from 'node:assert/strict';
import * as THREE from 'three';
import {ActingDirector,actingSample} from '../assets/avatar/acting-director.js';
import {CornealCatchlights} from '../assets/avatar/eye-materials.js';

function setup(){
  const model=new THREE.Group();
  for(const [name,x,y]of [['Head',0,1],['EyeL',.04,1.08],['EyeR',-.04,1.08],['Hair',0,1.2]]){
    const b=new THREE.Bone();b.name=name;b.position.set(x,y,.05);model.add(b);
  }
  const rig={head:'Head',eyes:['EyeL','EyeR'],hair:[{name:'Hair'}]};
  return {model,rig,director:new ActingDirector(model,rig)};
}

test('attention leads shoulders and the story joins continuously at its boundary',()=>{
  const a=actingSample(2.1);assert.ok(a.gaze>a.head&&a.head>a.body);
  for(let t=0;t<36;t+=1/120){
    const a=actingSample(t),b=actingSample(t+1/120);
    for(const k in a){assert.ok(Number.isFinite(a[k]));assert.ok(Math.abs(a[k]-b[k])<.015,k+' must not jump');}
  }
});

test('layered head motion preserves eye/hair spacing, restores the source pose and keeps lip closure',()=>{
  const {model,director}=setup();const eye=model.getObjectByName('EyeL'),hair=model.getObjectByName('Hair');
  const distance=eye.position.distanceTo(hair.position),rest=eye.position.clone();let low=Infinity,high=-Infinity;
  for(let i=0;i<3600;i++){
    director.restore();assert.ok(eye.position.distanceTo(rest)<1e-7,'no accumulated deformation');
    const w={MBP:1,Blink:0};director.update(1/60,w,{engaged:true,speaking:true});
    assert.ok(Math.abs(eye.position.distanceTo(hair.position)-distance)<1e-7);
    assert.equal(w.MBP,1);assert.ok(w.SmileLeft<=.22+1e-9);
    assert.ok(!w.Emotion_happy&&!w.Emotion_confused);
    low=Math.min(low,model.rotation.y);high=Math.max(high,model.rotation.y);
  }
  assert.ok(high-low>.65,'real body turns, not only an eye shift');
});

test('catchlights stay on the eye surface through model turns and use lid depth occlusion',()=>{
  const {model,rig}=setup(),glints=new CornealCatchlights(model,rig),camera=new THREE.PerspectiveCamera();
  camera.position.set(0,1.65,1.37);
  for(const angle of [-.25,0,.65]){
    model.rotation.y=angle;glints.update(camera);
    for(const {eye,spot}of glints.eyePairs){assert.ok(Math.abs(spot.position.distanceTo(eye.position)-.0437)<1e-7);assert.equal(spot.material.depthTest,true);assert.ok(spot.position.toArray().every(Number.isFinite));}
  }
});
