import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import {isIOSBrowser,prepareMobileModel} from '../assets/avatar/mobile-memory.js';
import {DataUtils} from '../assets/avatar/vendor/three.core.js';
import {RenderQuality} from '../assets/avatar/render-quality.js';

test('iPhone Safari, WeChat and touch iPad get the memory budget; desktop does not',()=>{
  for(const userAgent of ['Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) Version/18 Safari/605','Mozilla/5.0 (iPhone) AppleWebKit/605 MicroMessenger/8'])assert.equal(isIOSBrowser({userAgent}),true);
  assert.equal(isIOSBrowser({platform:'MacIntel',maxTouchPoints:5}),true);
  assert.equal(isIOSBrowser({platform:'MacIntel',maxTouchPoints:0}),false);
  assert.equal(isIOSBrowser({userAgent:'Windows Chrome/140'}),false);
});

test('mobile reuses resized shared textures, preserves face resolution and all morph channels',async()=>{
  let closed=0,calls=0;const hair={width:2048,height:2048,close:()=>closed++},face={width:2048,height:2048};
  const source={data:hair};
  const texture=()=>({isTexture:true,source,get image(){return this.source.data;},set image(value){this.source.data=value;}});
  const a=texture(),b=texture(),head={isTexture:true,image:face};
  const geometry={userData:{},morphAttributes:{position:Array(52).fill({})}};
  const root={traverse:fn=>{
    fn({isMesh:true,geometry,material:{name:'Runtime_storm_hair_clumps',map:a,normalMap:b}});
    fn({isMesh:true,geometry:{userData:{},morphAttributes:{}},material:{name:'Runtime_storm_head',map:head}});
  }};
  const stats=await prepareMobileModel(root,{enabled:true,resizeImage:async(image,width,height)=>{calls++;return {width,height};}});
  assert.equal(calls,1);assert.equal(closed,1);assert.equal(a.image,b.image);assert.equal(a.image.width,1024);
  assert.equal(head.image,face);assert.equal(geometry.morphAttributes.position.length,52);
  assert.equal(geometry.userData.morphTextureHalfFloat,true);assert.equal(stats.resizedImages,1);
  assert.ok(stats.textureBytesAfter<stats.textureBytesBefore);
});

test('desktop model remains untouched',async()=>{
  const report=await prepareMobileModel({traverse:()=>{throw Error('desktop mutation');}},{enabled:false});
  assert.equal(report.enabled,false);
});

test('mobile budget survives manual high mode without reducing requested high-refresh cadence',()=>{
  const q=new RenderQuality({pixelRatio:3,cadence:120,memoryConstrained:true});
  q.configure({quality:'high',adaptive:false});assert.equal(q.ratio,1);assert.equal(q.profile.shadow,512);assert.equal(q.targetFps,120);
});

test('half-float storage retains actual Storm position and normal morphs within small error bounds',()=>{
  const bytes=fs.readFileSync(new URL('../assets/avatar/models/storm-performance.glb',import.meta.url));
  const jsonLength=bytes.readUInt32LE(12),g=JSON.parse(bytes.toString('utf8',20,20+jsonLength)),offset=20+jsonLength+8;
  let positions=0,normals=0,maxPositionError=0,maxNormalError=0;
  for(const mesh of g.meshes)for(const p of mesh.primitives)for(const target of p.targets||[]){
    for(const semantic of ['POSITION','NORMAL']){
      if(target[semantic]===undefined)continue;
      const a=g.accessors[target[semantic]];assert.equal(a.componentType,5126);
      const sources=[];
      if(a.bufferView!==undefined)sources.push({view:a.bufferView,byteOffset:a.byteOffset||0,count:a.count});
      if(a.sparse)sources.push({view:a.sparse.values.bufferView,byteOffset:a.sparse.values.byteOffset||0,count:a.sparse.count});
      for(const item of sources){
      const v=g.bufferViews[item.view],start=offset+(v.byteOffset||0)+item.byteOffset;
      for(let i=0;i<item.count*3;i+=29){
        const value=bytes.readFloatLE(start+i*4),error=Math.abs(DataUtils.fromHalfFloat(DataUtils.toHalfFloat(value))-value);
        if(semantic==='POSITION'){positions++;maxPositionError=Math.max(maxPositionError,error);}else{normals++;maxNormalError=Math.max(maxNormalError,error);}
      }
      }
    }
  }
  assert.ok(positions>100000&&normals>100000);
  // Less than 0.2mm in model coordinates (0.3mm after the scene's 1.5 scale).
  assert.ok(maxPositionError<.0002,`position error ${maxPositionError}`);
  assert.ok(maxNormalError<.002,`normal error ${maxNormalError}`);
});

test('service-worker cleanup never reloads or prevents Flutter startup',async()=>{
  const source=fs.readFileSync(new URL('../web/flutter_bootstrap.js',import.meta.url),'utf8').replace('{{flutter_js}}','').replace('{{flutter_build_config}}','');
  for(const restricted of [false,true]){
    let started=0,unregistered=0;
    const context={document:{baseURI:'https://test.invalid/'},URL,location:{reload:()=>{throw Error('automatic reload');}},navigator:{serviceWorker:{controller:{},getRegistrations:async()=>{
      if(restricted)throw Error('storage denied');
      return [{scope:'https://test.invalid/',unregister:async()=>{unregistered++;return true;}}];
    }}},_flutter:{loader:{load:()=>started++}}};
    for(let visit=0;visit<2;visit++)await vm.runInNewContext(source,context);
    assert.equal(started,2);assert.equal(unregistered,restricted?0:2);
  }
});
