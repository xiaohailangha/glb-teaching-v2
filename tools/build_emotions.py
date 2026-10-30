"""Bake twelve original six-second acting studies on the official Snow rig.
Input: work/performance-render-eyes.blend. Background Blender only.
"""
import bpy,pathlib,sys,json,re,math,struct,copy
import numpy as np
root=pathlib.Path(__file__).resolve().parents[1];sys.path.insert(0,str(root/'tools'))
from pack_glb import pack
r=bpy.data.objects['RIG-Snow'];actor=bpy.data.objects['Snow_Performance']
items=json.loads((root/'assets/data/emotions.json').read_text(encoding='utf8'))
face_only='--face-only' in sys.argv
initial={p.name:(p.location.copy(),p.rotation_euler.copy(),p.rotation_quaternion.copy(),p.scale.copy()) for p in r.pose.bones}
def reset():
 for name,(loc,rot,quat,scale) in initial.items():
  p=r.pose.bones[name];p.location=loc;p.rotation_euler=rot;p.rotation_quaternion=quat;p.scale=scale
def update():
 r.update_tag();bpy.context.view_layer.update();return bpy.context.evaluated_depsgraph_get()
def pose(name,amount,eyelids=False):
 a=bpy.data.actions[name]
 for layer in a.layers:
  for strip in layer.strips:
   for bag in strip.channelbags:
    for f in bag.fcurves:
     m=re.fullmatch(r'pose.bones\["(.+?)"\]\.(location|rotation_euler|rotation_quaternion|scale)',f.data_path)
     if not m or (eyelids and not any(s in m[1] for s in ['Eyelid','Eye_Ring'])):continue
     if r.pose.bones.get(m[1]):
      arr=getattr(r.pose.bones[m[1]],m[2]);arr[f.array_index]+=(f.evaluate(a.frame_range[0])-arr[f.array_index])*amount
def coord(source,dg):
 ev=source.evaluated_get(dg);m=ev.to_mesh();a=np.empty(len(m.vertices)*3,dtype=np.float32);m.vertices.foreach_get('co',a);ev.to_mesh_clear();return a
faces={
 'happy':[('Mouth Teethsmile',.95),('Eyemask Relaxed',.12)],
 'sad':[('Eyemask Sad',.9),('Mouth Openfrown',.30)],
 'frustrated':[('Eyemask Angry',.45),('Mouth Compressed',.65)],
 'afraid':[('Eyemask Scared',.9),('Mouth Teethfrown',.7)],
 'angry':[('Eyemask Angry',.95),('Mouth Teethfrown',.45)],
 'surprised':[('Eyemask Scared',.72),('Mouth Oo',.75)],
 'curious':[('Eyemask Cocky',.7),('Mouth Opensmile',.20)],
 'confused':[('Eyemask Cocky',.95),('Mouth Narrow',.35)],
 'shy':[('Eyemask Sad',.20),('Mouth Teethsmile',.52)],
 'proud':[('Eyemask Cocky',.35),('Mouth Teethsmile',.68)],
 'disgusted':[('Eyemask Compressed',.65),('Mouth Ff',.55)],
 'relieved':[('Eyemask Relaxed',.22),('Mouth Teethsmile',.55)]}
parts=['head','eyebrows','teeth_upper','teeth_lower','gums_upper','gums_lower','tongue']
pairs=[(bpy.data.objects['GEO-snow-'+p],bpy.data.objects['Snow_'+p]) for p in parts]
pairs += [(bpy.data.objects['GEO-snow-eyes'],bpy.data.objects['Snow_eyes']),(bpy.data.objects['GEO-snow_eye_corneas'],bpy.data.objects['Snow_corneas'])]
report={'faces':{},'seconds_per_emotion':6,'sample_rate':20}
reset();dg=update()
for item in items:
 name=item['id'];reset()
 for action,amount in faces[name]:pose(action,amount)
 if name in ['happy','shy','proud','relieved']:
  for side in ['L','R']:
   r.pose.bones['CheekRaiser.'+side].location.y=.005 if name=='happy' else .002
   r.pose.bones['MSTR-Eyelid_Lower.'+side].location.y=.003
 if name=='disgusted':r.pose.bones['MSTR-Lip_Top'].location.y=.004
 if name=='confused':r.pose.bones['MSTR-Eyebrow.L'].location.y=.012
 if name=='curious':r.pose.bones['MSTR-Eyebrow.R'].location.y=.009
 if name in ['curious','confused']:
  for side in ['L','R']:r.pose.bones['MSTR-Eyelid_Upper.'+side].location.y+=.006 if name=='curious' else .004
 dg=update();opened={}
 for source,obj in pairs:
  a=coord(source,dg);base=np.empty(len(a),dtype=np.float32);obj.data.shape_keys.key_blocks['Basis'].data.foreach_get('co',base)
  delta=float(np.max(np.abs(a-base)));opened[obj.name]=(a,base)
  if delta<1e-5:continue
  key=obj.data.shape_keys.key_blocks.get('Emotion_'+name) or obj.shape_key_add(name='Emotion_'+name);key.data.foreach_set('co',a)
  report['faces'][obj.name+'_'+name]=delta
 # Add a differential lid-closure pose relative to this emotion. It composes
 # with the expression instead of summing a neutral blink onto widened eyes.
 pose('Eyemask Closed',1,eyelids=True);dg=update()
 for source,obj in pairs:
  a,base=opened[obj.name];closed=coord(source,dg);delta=closed-a
  if np.max(np.abs(delta))<1e-5:continue
  key=obj.data.shape_keys.key_blocks.get('EmotionBlink_'+name) or obj.shape_key_add(name='EmotionBlink_'+name)
  key.data.foreach_set('co',base+delta)
 print('FACE',name,flush=True)
reset();dg=update();er=r.evaluated_get(dg)
rest={b.name:er.pose.bones[b.name].matrix.copy() for b in actor.data.bones}
bind={b.name:b.matrix_local.copy() for b in actor.data.bones}
if not face_only:actor.animation_data.action=None
hidden={o:o.hide_viewport for o in bpy.context.scene.objects if o.type=='MESH'}
for o in hidden:o.hide_viewport=True
# Head/chest Euler rotations, arm spread (z), forward forearm bends,
# wrist rotation, shoulder lift. Each emotion has its own physical intention.
body={
 'happy':[-.035,0,.04,-.035,0,.025, .90,-.90,1.55,1.6,-.3,.4,.010],
 'sad':[.22,-.10,.06,.12,0,0,1.4,-1.4,.50,.70,.10,-.10,-.006],
 'frustrated':[.10,0,0,.06,0,0,1.05,-1.05,1.7,1.7,-.6,.65,.012],
 'afraid':[-.13,-.14,-.07,-.12,.08,-.03,.90,-.90,2.12,2.20,-.2,.2,.019],
 'angry':[.09,0,0,.10,0,0,1.12,-1.12,1.0,1.15,0,0,.013],
 'surprised':[-.15,.02,0,-.09,0,0,.78,-.78,2.25,2.25,-.20,.20,.020],
 'curious':[.04,-.17,-.13,.055,-.06,-.035,1.3,-1.02,.20,1.7,0,.65,.004],
 'confused':[.055,.07,.14,.015,.04,.045,1.07,-.95,1.60,1.85,-.6,.55,.012],
 'shy':[.13,.20,-.12,.035,.10,-.02,1.4,-1.4,1.25,1.4,.25,-.25,.010],
 'proud':[-.13,-.04,.04,-.09,-.03,0,.95,-.95,.90,.90,.25,-.25,-.002],
 'disgusted':[-.065,.30,-.08,-.10,.17,-.04,.90,-1.26,1.75,.4,-.15,0,.006],
 'relieved':[-.04,0,-.04,-.025,0,.015,1.23,-1.17,.85,1.05,-.25,.35,-.008]}
def smooth(v):v=max(0,min(1,v));return v*v*(3-2*v)
def envelope(t,name):
 attack=.55 if name in ['afraid','surprised'] else 1.15
 return smooth(t/attack)*(1-smooth((t-4.65)/1.35))
previous={};fps=20;bpy.context.scene.render.fps=fps;bpy.context.scene.frame_start=0;bpy.context.scene.frame_end=1440
for frame in ([] if face_only else range(1441)):
 t=frame/fps;index=min(11,int(t/6));local=min(6,t-index*6);name=items[index]['id'];a=envelope(local,name);b=body[name]
 bpy.context.scene.frame_set(frame);reset()
 for joint,offset in [('FK-Head',0),('FK-Chest',3)]:
  p=r.pose.bones[joint]
  for axis in range(3):p.rotation_euler[axis]+=b[offset+axis]*a
 # Small authored secondary reactions, kept below the main posture.
 if name=='frustrated':r.pose.bones['FK-Head'].rotation_euler.y+=.15*math.sin(local*5)*a
 if name=='confused':r.pose.bones['FK-Head'].rotation_euler.z+=.055*math.sin(local*2.1)*a
 if name=='happy':r.pose.bones['FK-Chest'].rotation_euler.x+=.025*math.sin(local*5)*a
 if name=='afraid':r.pose.bones['FK-Chest'].rotation_euler.z+=.008*math.sin(local*22)*a
 if name=='relieved':r.pose.bones['FK-Chest'].rotation_euler.x+=.04*math.sin(local*1.05)*a
 for side,spread,bend,wrist in [('R',b[6],b[8],b[10]),('L',b[7],b[9],b[11])]:
  p=r.pose.bones['FK-UpperArm.'+side];p.rotation_euler.z+=(spread-p.rotation_euler.z)*a;p.rotation_euler.x+=.12*a
  p=r.pose.bones['FK-Forearm.'+side];p.rotation_euler.x+=(bend-p.rotation_euler.x)*a
  r.pose.bones['FK-Wrist.'+side].rotation_euler.y+=wrist*a
  shoulder=r.pose.bones.get('FK-Shoulder.'+side)
  if shoulder:shoulder.location.y+=b[12]*a
 pose('Hand Relaxed',.55)
 # Clench the original finger FK joints in anger; no deformation shortcut.
 if name=='angry':
  for p in r.pose.bones:
   if p.name.startswith('FK-Finger') and 'Thumb' not in p.name:p.rotation_euler.x+=.45*a
 dg=update();er=r.evaluated_get(dg)
 for joint in bind:
  p=actor.pose.bones[joint];p.rotation_mode='QUATERNION'
  p.matrix_basis=bind[joint].inverted() @ er.pose.bones[joint].matrix @ rest[joint].inverted() @ bind[joint]
  if joint in previous and p.rotation_quaternion.dot(previous[joint])<0:p.rotation_quaternion.negate()
  previous[joint]=p.rotation_quaternion.copy()
  for prop in ['location','rotation_quaternion','scale']:p.keyframe_insert(data_path=prop,frame=frame,group=joint)
 if frame%120==0:print('BODY',frame,name,flush=True)
actor.animation_data.action.name='Emotion_Reel'
for layer in actor.animation_data.action.layers:
 for strip in layer.strips:
  for bag in strip.channelbags:
   for f in bag.fcurves:
    for k in f.keyframe_points:k.interpolation='LINEAR'
for o,visible in hidden.items():o.hide_viewport=visible
reset();bpy.context.scene.frame_set(0);update()
for o in bpy.context.selected_objects:o.select_set(False)
for o in bpy.data.collections['Snow_Runtime_Export'].objects:o.select_set(True)
bpy.context.view_layer.objects.active=actor
path=root/'work/snow-emotions-export.glb'
bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='ACTIVE_ACTIONS',export_nla_strips_merged_animation_name='Emotion_Reel',export_morph=True,export_morph_normal=True,export_skins=True,export_cameras=False,export_lights=False)
pack(path)
# Copy only the already-validated teaching animation buffers into this asset.
# Geometry, skin and texture data stay single-copy; targets map by unique names.
def read_glb(path):
 data=path.read_bytes();n=struct.unpack_from('<I',data,12)[0];doc=json.loads(data[20:20+n]);return doc,bytearray(data[28+n:])
old,oldbin=read_glb(root/'work/emotions-baseline/snow-performance.glb');doc,binary=read_glb(path)
node_ids={n.get('name'):i for i,n in enumerate(doc['nodes'])};accessors={};views={}
def copy_accessor(index):
 if index in accessors:return accessors[index]
 ac=copy.deepcopy(old['accessors'][index]);vi=ac['bufferView']
 if vi not in views:
  view=copy.deepcopy(old['bufferViews'][vi]);start=view.get('byteOffset',0);binary.extend(b'\0'*((-len(binary))%4))
  view['byteOffset']=len(binary);binary.extend(oldbin[start:start+view['byteLength']]);views[vi]=len(doc['bufferViews']);doc['bufferViews'].append(view)
 ac['bufferView']=views[vi];accessors[index]=len(doc['accessors']);doc['accessors'].append(ac);return accessors[index]
animation=copy.deepcopy(next(a for a in old['animations'] if a['name']=='Teaching_Apple_10s'))
for s in animation['samplers']:s['input']=copy_accessor(s['input']);s['output']=copy_accessor(s['output'])
for c in animation['channels']:c['target']['node']=node_ids[old['nodes'][c['target']['node']]['name']]
doc['animations'].insert(0,animation);doc['buffers'][0]['byteLength']=len(binary);binary.extend(b'\0'*((-len(binary))%4))
encoded=json.dumps(doc,separators=(',',':')).encode();encoded+=b' '*((-len(encoded))%4)
output=root/'assets/avatar/models/snow-performance.glb'
output.write_bytes(struct.pack('<III',0x46546c67,2,28+len(encoded)+len(binary))+struct.pack('<II',len(encoded),0x4e4f534a)+encoded+struct.pack('<II',len(binary),0x004e4942)+binary)
report['bytes']=output.stat().st_size
(root/'docs/emotions-model-report.json').write_text(json.dumps(report,indent=2))
bpy.ops.wm.save_as_mainfile(filepath=str(root/'work/performance-emotions.blend'))
print('EMOTIONS_READY',report['bytes'],flush=True)
