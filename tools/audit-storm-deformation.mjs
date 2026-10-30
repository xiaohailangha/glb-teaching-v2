import fs from 'node:fs';
import * as THREE from 'three';
import {GLTFLoader} from 'three/addons/loaders/GLTFLoader.js';

// CPU reference using the source asset, without images or a browser renderer.
const source = fs.readFileSync('assets/avatar/models/storm-performance.glb');
const jsonLength = source.readUInt32LE(12);
const document = JSON.parse(source.subarray(20, 20 + jsonLength));
for (const mesh of document.meshes) for (const primitive of mesh.primitives) delete primitive.material;
delete document.materials; delete document.textures; delete document.images;
let json = Buffer.from(JSON.stringify(document));
json = Buffer.concat([json, Buffer.alloc((4 - json.length % 4) % 4, 32)]);
const binary = source.subarray(20 + jsonLength);
const header = Buffer.alloc(20);
header.writeUInt32LE(0x46546c67); header.writeUInt32LE(2,4);
header.writeUInt32LE(20 + json.length + binary.length,8);
header.writeUInt32LE(json.length,12); header.writeUInt32LE(0x4e4f534a,16);
const data = Buffer.concat([header,json,binary]);
const gltf = await new GLTFLoader().parseAsync(data.buffer.slice(data.byteOffset,data.byteOffset+data.byteLength),'');
const mesh = gltf.scene.getObjectByName('Storm_trousers');
if (!mesh) throw Error('Missing source trousers');
const repaired=process.argv.includes('--repaired');
if(repaired){
 const manifest=JSON.parse(fs.readFileSync('scene-preview/assets/avatar/models/storm-clothing-bindings.json'));
 const bytes=fs.readFileSync('scene-preview/assets/avatar/models/storm-clothing-bindings.bin');
 const part=manifest.parts.find(p=>p.node==='Storm_trousers'),names=mesh.skeleton.bones.map(b=>b.name);
 const indices=new Float32Array(part.vertices*4),weights=new Float32Array(part.vertices*4);
 for(let v=0;v<part.vertices;v++)for(let k=0;k<4;k++){
  const sourceIndex=bytes.readFloatLE((part.floatOffset+v*8+k)*4);
  indices[v*4+k]=names.indexOf(THREE.PropertyBinding.sanitizeNodeName(manifest.jointNames[sourceIndex]));
  weights[v*4+k]=bytes.readFloatLE((part.floatOffset+v*8+4+k)*4);
  if(indices[v*4+k]<0)throw Error('Unmapped repair joint');
 }
 mesh.geometry.setAttribute('skinIndex',new THREE.BufferAttribute(indices,4));
 mesh.geometry.setAttribute('skinWeight',new THREE.BufferAttribute(weights,4));
}
const mixer = new THREE.AnimationMixer(gltf.scene);
mixer.clipAction(gltf.animations.find(clip=>clip.name==='Teaching_Apple_10s')).play();
const result=[];
for (const time of [0,.5,1,2,3,4,5,6,7,8,9,9.9]) {
 mixer.setTime(time); gltf.scene.updateMatrixWorld(true); mesh.skeleton.update();
 const position=mesh.geometry.getAttribute('position'); let highest=-Infinity, vertex=-1;
 const posed=new Float32Array(position.count*3);
 for(let i=0;i<position.count;i++) {const p=new THREE.Vector3().fromBufferAttribute(position,i);mesh.applyBoneTransform(i,p);p.toArray(posed,i*3);if(p.y>highest){highest=p.y;vertex=i;}}
 const triangles=mesh.geometry.index.array, rest=position.array;
 let maxEdgeStretch=0, worstTriangle=-1;
 for(let t=0;t<triangles.length;t+=3)for(let k=0;k<3;k++){
  const a=triangles[t+k]*3,b=triangles[t+(k+1)%3]*3;
  const edge=Math.hypot(rest[a]-rest[b],rest[a+1]-rest[b+1],rest[a+2]-rest[b+2]);
  if(edge<1e-5)continue;
  const stretch=Math.hypot(posed[a]-posed[b],posed[a+1]-posed[b+1],posed[a+2]-posed[b+2])/edge;
  if(stretch>maxEdgeStretch){maxEdgeStretch=stretch;worstTriangle=t/3;}
 }
 const joints=mesh.geometry.getAttribute('skinIndex'), weights=mesh.geometry.getAttribute('skinWeight');
 const index=new THREE.Vector4().fromBufferAttribute(joints,vertex),weight=new THREE.Vector4().fromBufferAttribute(weights,vertex);
 result.push({time,highest,vertex,maxEdgeStretch,worstTriangle,joints:index.toArray().map((j,i)=>({name:mesh.skeleton.bones[j].name,weight:weight.getComponent(i)}))});
}
fs.writeFileSync(`work/storm-trousers-${repaired?'repaired':'source'}-audit.json`,JSON.stringify(result,null,2));
if(repaired && result.some(frame=>frame.highest>.65 || frame.maxEdgeStretch>1.1))throw Error('Repaired trousers still stretch or rise with arms');
console.log(JSON.stringify({repaired,samples:result.length,maxHeight:Math.max(...result.map(f=>f.highest)),maxEdgeStretch:Math.max(...result.map(f=>f.maxEdgeStretch))}));
