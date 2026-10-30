import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

test('shipping model uses textured render eyes and a separate cornea with matching gaze targets',()=>{
  const bytes=fs.readFileSync(new URL('../assets/avatar/models/storm-performance.glb',import.meta.url));
  const doc=JSON.parse(bytes.toString('utf8',20,20+bytes.readUInt32LE(12)));
  assert.ok(!doc.nodes.some(n=>/eye.*anim/i.test(n.name)),'animation proxy must not ship');
  for(const name of ['Storm_eye.L','Storm_eye.R','Storm_eye_cornea.L','Storm_eye_cornea.R']){
    const node=doc.nodes.find(n=>n.name===name);assert.ok(node,name);assert.ok(node.skin!==undefined);
    const mesh=doc.meshes[node.mesh];
    for(const gaze of ['GazeLeft','GazeRight','GazeUp','GazeDown'])assert.ok(mesh.extras.targetNames.includes(gaze));
    for(const p of mesh.primitives)for(const target of p.targets)assert.ok(target.NORMAL!==undefined,'eye normals must follow gaze');
  }
  for(const name of ['Runtime_storm_eye.L','Runtime_storm_eye.R']){
    const eye=doc.materials.find(m=>m.name===name);
    assert.ok(eye.pbrMetallicRoughness.baseColorTexture);
  }
  const cornea=doc.materials.find(m=>m.name==='Runtime_storm-eyes-cornea');
  assert.equal(cornea.extensions.KHR_materials_transmission.transmissionFactor,1);
  assert.ok(cornea.pbrMetallicRoughness.roughnessFactor<.1);
});

test('Storm retains subdivision, original shader detail, and separately weighted hair chains',()=>{
  const bytes=fs.readFileSync(new URL('../assets/avatar/models/storm-performance.glb',import.meta.url));
  const doc=JSON.parse(bytes.toString('utf8',20,20+bytes.readUInt32LE(12)));
  for(const part of ['head','hair_clumps','hair_base']){
    const material=doc.materials.find(m=>m.name==='Runtime_storm_'+part);
    assert.ok(material.normalTexture,part+' strand/skin detail');
    assert.ok(material.pbrMetallicRoughness.metallicRoughnessTexture,part+' original roughness');
  }
  const head=doc.meshes[doc.nodes.find(n=>n.name==='Storm_head').mesh];
  assert.ok(doc.accessors[head.primitives[0].attributes.POSITION].count>50000,'rig drivers must not silently reset subdivision to zero');
  const jointNames=doc.skins[0].joints.map(i=>doc.nodes[i].name);
  assert.equal(jointNames.filter(n=>/Hair/.test(n)).length,42);
  assert.ok(jointNames.includes('FK-Eye.L')&&jointNames.includes('FK-Eye.R'));
});
