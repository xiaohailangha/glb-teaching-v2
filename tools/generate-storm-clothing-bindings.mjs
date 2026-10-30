import fs from 'node:fs';
import crypto from 'node:crypto';
const source=fs.readFileSync('assets/avatar/models/storm-performance.glb');
const length=source.readUInt32LE(12),g=JSON.parse(source.subarray(20,20+length)),bin=source.subarray(28+length);
function read(index){
 const a=g.accessors[index],v=g.bufferViews[a.bufferView],n={SCALAR:1,VEC2:2,VEC3:3,VEC4:4}[a.type];
 const [size,method]={5121:[1,'readUInt8'],5123:[2,'readUInt16LE'],5125:[4,'readUInt32LE'],5126:[4,'readFloatLE']}[a.componentType];
 return Array.from({length:a.count},(_,i)=>Array.from({length:n},(_,k)=>bin[method]((v.byteOffset||0)+(a.byteOffset||0)+i*(v.byteStride||n*size)+k*size)));
}
const jointNames=g.skins[0].joints.map(i=>g.nodes[i].name);
const allowed=name=>/^DEF-(Spine[12]$|Thigh_|Knee_|PantLeg)/.test(name);
const body=g.meshes[g.nodes.find(n=>n.name==='Storm_body').mesh].primitives[0];
const points=read(body.attributes.POSITION),bj=read(body.attributes.JOINTS_0),bw=read(body.attributes.WEIGHTS_0);
const candidates=points.map((p,i)=>({p,j:bj[i],w:bw[i]})).filter(v=>v.w.reduce((s,w,k)=>s+(allowed(jointNames[v.j[k]])?w:0),0)>.999);
if(candidates.length<100)throw Error('No anatomical body population');
function tree(values,depth=0){if(!values.length)return null;const axis=depth%3;values.sort((a,b)=>a.p[axis]-b.p[axis]);const m=values.length>>1;return {v:values[m],axis,left:tree(values.slice(0,m),depth+1),right:tree(values.slice(m+1),depth+1)};}
const trees=[tree(candidates.filter(v=>v.p[0]<=.005)),tree(candidates.filter(v=>v.p[0]>=-.005))];
function nearest(node,p,best={d:Infinity,v:null}){if(!node)return best;const d=node.v.p.reduce((s,x,k)=>s+(x-p[k])**2,0);if(d<best.d){best.d=d;best.v=node.v;}const diff=p[node.axis]-node.v.p[node.axis];nearest(diff<0?node.left:node.right,p,best);if(diff*diff<best.d)nearest(diff<0?node.right:node.left,p,best);return best;}
const values=[],parts=[],audit=[];
for(const node of g.nodes.filter(n=>n.name.startsWith('Storm_trousers'))){
 for(const [primitiveIndex,p] of g.meshes[node.mesh].primitives.entries()){
  const ps=read(p.attributes.POSITION),js=read(p.attributes.JOINTS_0),ws=read(p.attributes.WEIGHTS_0),changed=new Set();
  const offset=values.length;
  for(let i=0;i<ps.length;i++){
   let j=js[i],w=ws[i];
   if(w.some((v,k)=>v>1e-5&&!allowed(jointNames[j[k]]))){
    changed.add(i);const retained=w.map((v,k)=>allowed(jointNames[j[k]])?v:0),sum=retained.reduce((a,b)=>a+b,0);
    if(sum>.25){w=retained.map(v=>v/sum);}else{const found=nearest(trees[ps[i][0]<0?0:1],ps[i]).v;j=found.j;w=found.w;}
   }
   const sum=w.reduce((a,b)=>a+b,0);w=w.map(v=>v/sum);
   if(w.some((v,k)=>v>1e-5&&!allowed(jointNames[j[k]])))throw Error('Invalid repaired binding');
   values.push(...j,...w);
  }
  const indices=read(p.indices).flat();let affectedTriangles=0;for(let i=0;i<indices.length;i+=3)if(indices.slice(i,i+3).some(v=>changed.has(v)))affectedTriangles++;
  parts.push({node:node.name,primitive:primitiveIndex,vertices:ps.length,floatOffset:offset});
  audit.push({node:node.name,primitive:primitiveIndex,vertices:ps.length,changedVertices:changed.size,affectedTriangles});
 }
}
const bytes=Buffer.alloc(values.length*4);values.forEach((v,i)=>bytes.writeFloatLE(v,i*4));
const directory='scene-preview/assets/avatar/models';
fs.writeFileSync(directory+'/storm-clothing-bindings.bin',bytes);
const manifest={sourceSha256:crypto.createHash('sha256').update(source).digest('hex'),bindingsSha256:crypto.createHash('sha256').update(bytes).digest('hex'),jointNames,parts,audit};
fs.writeFileSync(directory+'/storm-clothing-bindings.json',JSON.stringify(manifest,null,2)+'\n');
console.log(JSON.stringify({bytes:bytes.length,candidates:candidates.length,audit}));
