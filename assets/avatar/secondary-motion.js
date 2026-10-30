import * as THREE from 'three';

// A bounded, damped response to actual head movement, not a looping wiggle.
export function springStep(state, drive, dt, frequency=10, damping=.72, limit=.075){
  const steps=Math.max(1,Math.ceil(Math.min(dt,.1)*120)),h=Math.min(dt,.1)/steps;
  for(let i=0;i<steps;i++){
    state.velocity+=(-frequency*frequency*state.value-2*damping*frequency*state.velocity+drive)*h;
    state.value+=state.velocity*h;
    if(Math.abs(state.value)>limit){state.value=Math.sign(state.value)*limit;state.velocity*=.25;}
  }
  return state.value;
}

const boneFor=(model,name)=>model.getObjectByName(THREE.PropertyBinding.sanitizeNodeName(name));

export class EyeAim {
  constructor(model,rig){
    this.eyes=rig.eyes.map(n=>boneFor(model,n)).filter(Boolean);
    this.head=rig.head?boneFor(model,rig.head):null;
    this.rest=this.eyes.map(b=>b.quaternion.clone());this.applied=false;
    this.center=new THREE.Vector3();this.target=new THREE.Vector3();this.direction=new THREE.Vector3();this.forward=new THREE.Vector3();this.delta=new THREE.Quaternion();
  }
  restore(){if(this.applied)this.eyes.forEach((b,i)=>b.quaternion.copy(this.rest[i]));this.applied=false;}
  update(weights,bodyYaw=0){
    if(this.eyes.length!==2)return;
    this.center.copy(this.eyes[0].position).add(this.eyes[1].position).multiplyScalar(.5);
    // Both eyes converge on one distant point. Never offset pupils independently.
    this.target.set(0,0,3);
    if(this.head)this.target.applyQuaternion(this.head.quaternion);
    // Learner stays in world space while the shoulders turn.
    const learner=new THREE.Vector3(-3*Math.sin(bodyYaw),0,3*Math.cos(bodyYaw));
    this.target.lerp(learner,bodyYaw===0?.4:.68);
    this.target.add(this.center).add(new THREE.Vector3(.65*((weights.GazeRight||0)-(weights.GazeLeft||0)),.4*((weights.GazeUp||0)-(weights.GazeDown||0)),0));
    this.eyes.forEach((b,i)=>{
      this.rest[i].copy(b.quaternion);
      // The GLB exporter converts Storm's forward eye basis to local +Z.
      this.forward.set(0,0,1).applyQuaternion(b.quaternion).normalize();
      this.direction.copy(this.target).sub(b.position).normalize();
      this.delta.setFromUnitVectors(this.forward,this.direction);
      const angle=2*Math.acos(Math.min(1,Math.abs(this.delta.w)));
      if(angle>.35)this.delta.slerp(new THREE.Quaternion(),1-.35/angle);
      b.quaternion.premultiply(this.delta);b.updateMatrix();
    });this.applied=true;
  }
}

export class HairDynamics {
  constructor(model,rig){
    this.head=boneFor(model,rig.head);this.previous=null;this.applied=false;this.peak=0;
    this.euler=new THREE.Euler();this.lastEuler=new THREE.Vector3();
    this.worldQ=new THREE.Quaternion();this.lastWorldQ=new THREE.Quaternion();this.changeQ=new THREE.Quaternion();
    this.records=new Map();
    for(const entry of rig.hair){
      const bone=boneFor(model,entry.name);if(!bone)continue;
      this.records.set(entry.name,{...entry,bone,p:bone.position.clone(),q:bone.quaternion.clone(),s:bone.scale.clone(),base:new THREE.Matrix4(),inverse:new THREE.Matrix4(),delta:new THREE.Matrix4(),working:new THREE.Matrix4(),bend:new THREE.Quaternion(),x:{value:0,velocity:0},y:{value:0,velocity:0},z:{value:0,velocity:0},done:false});
    }
  }
  restore(){if(this.applied)for(const r of this.records.values()){r.bone.position.copy(r.p);r.bone.quaternion.copy(r.q);r.bone.scale.copy(r.s);}this.applied=false;}
  update(dt,weights={}){
    if(!this.head||dt<=0)return;
    this.head.getWorldQuaternion(this.worldQ);
    this.changeQ.copy(this.lastWorldQ).invert().multiply(this.worldQ);
    if(this.changeQ.w<0){this.changeQ.x*=-1;this.changeQ.y*=-1;this.changeQ.z*=-1;this.changeQ.w*=-1;}
    const angle=2*Math.acos(Math.min(1,this.changeQ.w)),sin=Math.sqrt(Math.max(0,1-this.changeQ.w*this.changeQ.w));
    const speed=this.previous&&sin>1e-6?Math.min(6,angle/dt)/sin:0;
    const vx=this.changeQ.x*speed,vy=this.changeQ.y*speed,vz=this.changeQ.z*speed;
    this.previous=true;this.lastWorldQ.copy(this.worldQ);
    for(const r of this.records.values()){
      r.p.copy(r.bone.position);r.q.copy(r.bone.quaternion);r.s.copy(r.bone.scale);
      r.base.compose(r.p,r.q,r.s);r.inverse.copy(r.base).invert();r.done=false;
    }
    const solve=(r,depth=0)=>{
      if(r.done)return;r.done=true;
      const parent=this.records.get(r.parent);if(parent)solve(parent,depth+1);
      r.working.copy(r.base);if(parent)r.working.premultiply(parent.delta);
      r.working.decompose(r.bone.position,r.bone.quaternion,r.bone.scale);
      const anchored=r.name==='MSTR-Hair';
      const tip=/_\d$|2\./.test(r.name),frequency=tip?8:11,gain=tip?10:6;
      const ax=springStep(r.x,anchored?0:-vx*gain,dt,frequency,.72,tip?.15:.075);
      const ay=springStep(r.y,anchored?0:-vy*gain,dt,frequency,.72,tip?.13:.065);
      const az=springStep(r.z,anchored?0:-vz*gain,dt,frequency,.72,tip?.15:.075);
      this.peak=Math.max(this.peak,Math.abs(ax),Math.abs(ay),Math.abs(az));
      r.bend.setFromEuler(new THREE.Euler(ax,ay,az));r.bone.quaternion.premultiply(r.bend);
      r.bone.updateMatrix();r.delta.copy(r.bone.matrix).multiply(r.inverse);
    };
    for(const r of this.records.values())solve(r);
    this.applied=true;
  }
}
