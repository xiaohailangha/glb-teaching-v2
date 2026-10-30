import * as THREE from 'three';

// A small, static studio reflection is generated once, never per frame.
// Only eyes use it, so restoring the corneal catchlight leaves skin unchanged.
export function makeEyeEnvironment(renderer){
  const studio=new THREE.Scene();studio.background=new THREE.Color(.035,.045,.055);
  const cards=[];
  for(const [x,y,z,w,h,intensity]of [[-2,3,4,2,3,4],[3,1,2,1,2,.8]]){
    const card=new THREE.Mesh(new THREE.PlaneGeometry(w,h),new THREE.MeshBasicMaterial({color:new THREE.Color().setScalar(intensity),side:THREE.DoubleSide}));
    card.position.set(x,y,z);card.lookAt(0,0,0);studio.add(card);cards.push(card);
  }
  // A compact softbox creates a readable, moving corneal catchlight.
  const catchlight=new THREE.Mesh(new THREE.SphereGeometry(.48,24,16),new THREE.MeshBasicMaterial({color:new THREE.Color(12,12,12)}));
  catchlight.position.set(-2,2.7,6);studio.add(catchlight);cards.push(catchlight);
  const generator=new THREE.PMREMGenerator(renderer);
  const result=generator.fromScene(studio,0,.1,30);generator.dispose();
  for(const card of cards){card.geometry.dispose();card.material.dispose();}
  return result;
}

export function configureEyeMaterial(material,environment){
  if(material.name==='Runtime_snow.eyes'||/^Runtime_storm_eye\.[LR]$/.test(material.name)){
    material.roughness=.32;material.metalness=0;material.envMap=environment;
    material.envMapIntensity=.35;
    return true;
  }
  if(material.name==='Runtime_snow.eyes_cornea'||material.name==='Runtime_storm-eyes-cornea'){
    material.roughness=.035;material.ior=1.376;material.transmission=1;
    material.thickness=0;material.envMap=environment;material.envMapIntensity=1.65;
    material.side=THREE.DoubleSide;
    material.onBeforeCompile=shader=>{
      // Small studio key reflected by the curved cornea; follows the actual
      // skinned surface normal and view angle rather than a painted pupil dot.
      shader.fragmentShader=shader.fragmentShader.replace('#include <opaque_fragment>',`
        vec3 eyeReflection = reflect(-normalize(vViewPosition), normal);
        float eyeKey = pow(max(dot(eyeReflection, normalize(vec3(-0.32, 0.48, 1.0))), 0.0), 260.0);
        outgoingLight += vec3(3.5) * eyeKey;
        #include <opaque_fragment>
      `);
    };
    material.customProgramCacheKey=()=> 'storm-cornea-catchlight-v3';
    return true;
  }
  return false;
}

// A tiny geometric softbox reflection keeps the catchlight legible when a
// transmission buffer loses subpixel highlights. It is depth-tested against
// lids and follows the view/light half-vector on the curved eye surface.
export class CornealCatchlights {
  constructor(model,rig){
    this.model=model;this.eyePairs=[];
    this.view=new THREE.Vector3();this.light=new THREE.Vector3(-2,3,6);this.half=new THREE.Vector3();
    this.inverse=new THREE.Matrix4();this.cameraLocal=new THREE.Vector3();this.lightLocal=new THREE.Vector3();
    for(const name of rig.eyes){
      const eye=model.getObjectByName(THREE.PropertyBinding.sanitizeNodeName(name));if(!eye)continue;
      const spot=new THREE.Mesh(new THREE.CircleGeometry(.0017,16),new THREE.MeshBasicMaterial({color:0xffffff,toneMapped:false,depthWrite:false}));
      spot.name='Corneal_softbox_'+name;model.add(spot);this.eyePairs.push({eye,spot});
    }
  }
  update(camera,weights={}){
    this.model.updateMatrixWorld(true);this.inverse.copy(this.model.matrixWorld).invert();
    this.cameraLocal.copy(camera.position).applyMatrix4(this.inverse);this.lightLocal.copy(this.light).applyMatrix4(this.inverse);
    for(const {eye,spot} of this.eyePairs){
      this.view.copy(this.cameraLocal).sub(eye.position).normalize();
      this.half.copy(this.lightLocal).sub(eye.position).normalize().add(this.view).normalize();
      spot.position.copy(eye.position).addScaledVector(this.half,.0437);
      const blink=Math.max(weights.Blink||0,...Object.keys(weights).filter(n=>n.startsWith('EmotionBlink_')).map(n=>weights[n]||0));
      spot.scale.setScalar(Math.max(0,1-blink*4));spot.visible=blink<.25;
      spot.quaternion.setFromUnitVectors(new THREE.Vector3(0,0,1),this.view);
    }
  }
}
