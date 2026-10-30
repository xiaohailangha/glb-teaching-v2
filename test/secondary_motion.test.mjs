import test from 'node:test';
import assert from 'node:assert/strict';
import * as THREE from 'three';
import {springStep,EyeAim,HairDynamics} from '../assets/avatar/secondary-motion.js';

test('hair responds to motion, is bounded at low FPS, and settles when the head stops',()=>{
  const simulate=rate=>{const s={value:0,velocity:0};let peak=0;for(let i=0;i<rate*5;i++){springStep(s,i<rate*.4?-6:0,1/rate);peak=Math.max(peak,Math.abs(s.value));}return {s,peak};};
  for(const rate of [15,30,60,120]){const {s,peak}=simulate(rate);assert.ok(peak>.015&&peak<=.075);assert.ok(Math.abs(s.value)<.0001);assert.ok(Math.abs(s.velocity)<.0001);}
  assert.ok(Math.abs(simulate(30).peak-simulate(60).peak)<.004);
});

test('both rigid eyes aim at a common distant point without cumulative rotation',()=>{
  const model=new THREE.Group();const eyes=['Left','Right'].map((name,i)=>{const b=new THREE.Bone();b.name=name;b.position.set(i?-.042:.042,1.08,.058);model.add(b);return b;});
  const head=new THREE.Bone();head.name='Head';model.add(head);
  const aim=new EyeAim(model,{eyes:['Left','Right'],head:'Head'});
  for(const gaze of [{},{GazeRight:.8},{GazeLeft:1},{GazeUp:.7}]){
    aim.restore();aim.update(gaze);
    for(const b of eyes){const forward=new THREE.Vector3(0,0,1).applyQuaternion(b.quaternion);const wanted=aim.target.clone().sub(b.position).normalize();assert.ok(forward.angleTo(wanted)<1e-7);}
    const separation=new THREE.Vector3(0,0,1).applyQuaternion(eyes[0].quaternion).angleTo(new THREE.Vector3(0,0,1).applyQuaternion(eyes[1].quaternion));assert.ok(separation<.03,'no excessive convergence');
  }
  head.rotation.x=.4;aim.restore();aim.update({GazeDown:.5});assert.ok(aim.target.y-aim.center.y<-.7,'a lowered head must not stare upward through the eyelids');
  head.rotation.x=0;aim.restore();aim.update({});const baseline=eyes[0].quaternion.clone();for(let i=0;i<120;i++){aim.restore();aim.update({});}assert.ok(baseline.angleTo(eyes[0].quaternion)<1e-7);
});

test('hair chain returns to authored pose and does not accumulate offsets across frames',()=>{
  const model=new THREE.Group(),head=new THREE.Bone(),hair=new THREE.Bone();head.name='Head';hair.name='Hair';hair.position.set(.02,1.2,.01);model.add(head,hair);
  const motion=new HairDynamics(model,{head:'Head',hair:[{name:'Hair',parent:null}]});let moved=0;
  for(let i=0;i<600;i++){motion.restore();head.rotation.y=i<60?.25*Math.sin(i/60*Math.PI):0;motion.update(1/60);moved=Math.max(moved,hair.quaternion.angleTo(new THREE.Quaternion()));}
  assert.ok(moved>.003);assert.ok(hair.quaternion.angleTo(new THREE.Quaternion())<.0001);assert.ok(hair.position.distanceTo(new THREE.Vector3(.02,1.2,.01))<1e-7);
});

test('a whole-body turn drives hair even with a fixed local head, then settles without angle-wrap spikes',()=>{
  for(const rate of [30,60,120]){
    const model=new THREE.Group(),head=new THREE.Bone(),hair=new THREE.Bone();head.name='Head';hair.name='Hair_1';model.add(head,hair);
    const dynamics=new HairDynamics(model,{head:'Head',hair:[{name:'Hair_1',parent:null}]});
    let peak=0;
    for(let i=0;i<rate*8;i++){
      dynamics.restore();const t=i/rate;model.rotation.y=t<3?Math.PI*2*(t/3):Math.PI*2;
      dynamics.update(1/rate);peak=Math.max(peak,Math.abs(dynamics.records.get('Hair_1').y.value));
    }
    assert.ok(peak>.08&&peak<=.13,'visible but bounded inertia during a turn');
    assert.ok(hair.quaternion.angleTo(new THREE.Quaternion())<.0001,'motion decays after stopping');
  }
});
