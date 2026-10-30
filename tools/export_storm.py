"""Convert the supplied Storm rig in a separate, background Blender process.
Keep source rigs intact. Bake their evaluated faces, original material colors,
and constrained body joints into the app's existing animation contract.
"""
import bpy, pathlib, sys, json, re, math, ast
import numpy as np
from mathutils import Vector
from mathutils.kdtree import KDTree
root=pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0,str(root/'tools'))
from performance_skeleton import TRACKS,sample
from storm_materials import bake_material
r=bpy.data.objects['RIG-storm']; out=root/'work/storm';out.mkdir(exist_ok=True,parents=True)
if r.animation_data:
 r.animation_data.action=None
 for t in r.animation_data.nla_tracks:t.mute=True
props=r.pose.bones['Properties'];props['ik_left_arm']=0.;props['ik_right_arm']=0.;props['Spine_ik']=0.
r.pose.bones['Properties_Character_Storm']['Anim Eyes']=False
r.pose.bones['FK-UpperArm.L'].rotation_euler.z=-1.32
r.pose.bones['FK-UpperArm.R'].rotation_euler.z=1.32
for side in ['L','R']:r.pose.bones['FK-Forearm.'+side].rotation_euler.x=-.08
initial={p.name:(p.location.copy(),p.rotation_euler.copy(),p.rotation_quaternion.copy(),p.scale.copy(),{k:p[k] for k in p.keys() if isinstance(p[k],(float,int,bool))}) for p in r.pose.bones}
def reset():
 for name,(loc,rot,quat,scale,pr) in initial.items():
  p=r.pose.bones[name];p.location=loc;p.rotation_euler=rot;p.rotation_quaternion=quat;p.scale=scale
  for k,v in pr.items():p[k]=v
def update():
 r.update_tag();bpy.context.view_layer.update();return bpy.context.evaluated_depsgraph_get()
def pose(name,amount=1,region=None):
 for l in bpy.data.actions[name].layers:
  for s in l.strips:
   for bag in s.channelbags:
    for f in bag.fcurves:
     m=re.fullmatch(r'pose.bones\["(.+?)"\]\.(location|rotation_euler|rotation_quaternion|scale)',f.data_path)
     if not m:continue
     bone,prop=m.groups()
     if region=='mouth' and not any(x in bone for x in ['Lip','lip','Jaw','Cheek','Teeth','Tongue']):continue
     if region=='eyes' and not any(x in bone for x in ['Eye','Brow','brow']):continue
     p=r.pose.bones.get(bone)
     if p:
      arr=getattr(p,prop);arr[f.array_index]+=(f.evaluate(1)-arr[f.array_index])*amount
def move(name,xyz):
 p=r.pose.bones[name];p.location+=p.bone.matrix_local.to_3x3().inverted()@Vector(xyz)
def blink():
 for side in ['L','R']:
  p=r.pose.bones['PRP-Eye_blink.'+side]
  # CloudRig's primary blink control drives both upper and lower eyelids.
  # The actual rig driver is TMP-Properties.Blink = -location.y * 30.
  p.location.y=-1/30
def coords(obj,dg):
 ev=obj.evaluated_get(dg);m=ev.to_mesh();a=np.empty(len(m.vertices)*3,dtype=np.float32);m.vertices.foreach_get('co',a);ev.to_mesh_clear();return a
exclude=['eye_anim','eye_dots','trousers_frills','socks','wristwatch_glass']
sources=[o for o in bpy.context.scene.objects if o.name.startswith('GEO-storm-') and o.type=='MESH' and not any(x in o.name for x in exclude)]
for o in sources:
 o.hide_set(False);o.hide_viewport=False
 for m in o.modifiers:
  if m.type=='SUBSURF':
   # CloudRig drives viewport subdivision from its rig properties. Remove only
   # these export-process drivers; otherwise reset()/depsgraph silently restores 0.
   for prop in ['levels','render_levels','show_viewport']:
    try:m.driver_remove(prop)
    except (TypeError,RuntimeError):pass
   m.show_viewport=True
   m.levels=2 if o.name in ['GEO-storm-head','GEO-storm-hair_clumps','GEO-storm-hair_base'] else 1 if o.name in ['GEO-storm-body','GEO-storm-top','GEO-storm-trousers','GEO-storm-eye.L','GEO-storm-eye.R','GEO-storm-eye_cornea.L','GEO-storm-eye_cornea.R'] else 0
   m.render_levels=m.levels
reset();dg=update()
col=bpy.data.collections.new('Storm_Runtime_Export');bpy.context.scene.collection.children.link(col)
baked={};base={};stats={'meshes':{},'morphs':{},'source':'storm_v1.1.blend'}
for src in sources:
 mesh=bpy.data.meshes.new_from_object(src.evaluated_get(dg),preserve_all_data_layers=True,depsgraph=dg)
 indexes=[p.material_index for p in mesh.polygons];mesh.materials.clear()
 for s in src.material_slots:mesh.materials.append(s.material)
 for p,i in zip(mesh.polygons,indexes):p.material_index=i;p.use_smooth=True
 obj=bpy.data.objects.new(src.name.replace('GEO-storm-','Storm_'),mesh);col.objects.link(obj);obj.matrix_world=src.matrix_world.copy()
 baked[src.name]=obj;base[src.name]=coords(src,dg)
 stats['meshes'][obj.name]={'vertices':len(mesh.vertices),'faces':len(mesh.polygons)}

# Bake original shader base colors on a separate UV map. Existing material UVs
# stay active for texture evaluation; no light/shadow is painted into the map.
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=1
for obj in bpy.context.scene.objects:
 if obj.type=='MESH':obj.hide_render=True
runtime_mats={}
def solid(mat):
 if mat.name in runtime_mats:return runtime_mats[mat.name]
 new=bpy.data.materials.new('Runtime_'+mat.name);new.use_nodes=True;bs=next(n for n in new.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
 color=None
 for n in mat.node_tree.nodes:
  if n.type in ['GROUP','BSDF_PRINCIPLED'] and 'Base Color' in n.inputs:
   color=n.inputs['Base Color'].default_value[:];break
 if color is None:color=mat.diffuse_color[:]
 bs.inputs['Base Color'].default_value=color;bs.inputs['Roughness'].default_value=.60
 if 'cornea' in mat.name:
  bs.inputs['Base Color'].default_value=(1,1,1,1);bs.inputs['Roughness'].default_value=.035;bs.inputs['Transmission Weight'].default_value=1;bs.inputs['IOR'].default_value=1.376
 if 'metal' in mat.name:bs.inputs['Metallic'].default_value=.7
 runtime_mats[mat.name]=new;return new
for src in sources:
 obj=baked[src.name];part=src.name.removeprefix('GEO-storm-')
 if part in ['head','body','hair_base','hair_clumps','top','trousers','eye.L','eye.R']:
  bake_material(obj,part,root/'work/storm-fidelity/textures-subdiv2')
 else:
  for slot in obj.material_slots:
   if slot.material:slot.material=solid(slot.material)

# The same morph names let all existing teaching and emotion blending remain.
for obj in baked.values():obj.shape_key_add(name='Basis')
face_parts={'head','eyebrows','gums_bottom','gums_top','teeth_bottom','teeth_top','tongue','eye.L','eye.R','eye_cornea.L','eye_cornea.R'}
emotions={'happy':('Face_Smile',.85),'sad':('Face_Concerned',.85),'frustrated':('Face_Annoyed',.85),'afraid':('Face_Scared',.85),'angry':('Face_Angry',.85),'surprised':('Face_Scared',.6),'curious':('Face_Smirk',.50),'confused':('Face_Concerned',.65),'shy':('Face_Smile',.4),'proud':('Face_Smirk',.75),'disgusted':('Face_Compressed',.65),'relieved':('Face_Smile',.5)}
targets=['AA','EE','OO','UU','FF','MBP','TH','L','Smile','Blink','BrowUp','BrowRelax','HeadNod','LookRight','LookLeft','Breathe','Gesture','GazeRight','GazeLeft','GazeUp','GazeDown','Warm','Curious','BrowLeft','BrowRight','SmileLeft','SmileRight','SmileEyes','Attentive']+['Emotion_'+e for e in emotions]
def expression(name):
 if name.startswith('Emotion_'):
  e=name[8:];action,amount=emotions[e];pose(action,amount)
  if e=='surprised':r.pose.bones['DEF-Jaw'].rotation_euler.x=-.25
  if e in ['curious','confused']:move('CTL-Brow_all.L',(0,0,.008))
 elif name=='AA':r.pose.bones['DEF-Jaw'].rotation_euler.x=-.32
 elif name=='EE':pose('Face_Smile',.6,'mouth')
 elif name in ['OO','UU']:
  r.pose.bones['DEF-Jaw'].rotation_euler.x=-.19 if name=='OO' else -.08
  for side,sign in [('L',1),('R',-1)]:move('CTL-Lips_corn.'+side,(-sign*.018,-.008,0))
  move('CTL-Lips_main_upp',(0,-.006,.002));move('CTL-Lips_main_low',(0,-.006,-.002))
 elif name=='FF':
  r.pose.bones['DEF-Jaw'].rotation_euler.x=-.045;move('CTL-Lips_main_low',(0,.004,.004));move('CTL-Lips_main_upp',(0,0,.002))
 elif name=='MBP':
  move('CTL-Lips_main_low',(0,0,.002));move('CTL-Lips_main_upp',(0,0,-.001))
 elif name in ['TH','L']:
  r.pose.bones['DEF-Jaw'].rotation_euler.x=-.11
  move('MSTR-Tongue',(0,-.016,.002) if name=='TH' else (0,-.008,.005))
 elif name in ['Smile','SmileLeft','SmileRight']:pose('Face_Smile',.42,'mouth')
 elif name=='Blink':blink()
 elif name in ['BrowLeft','BrowRight','BrowUp','Attentive']:
  sides=['L'] if name=='BrowLeft' else ['R'] if name=='BrowRight' else ['L','R']
  for side in sides:move('CTL-Brow_all.'+side,(0,0,.008))
 elif name in ['BrowRelax','Warm','SmileEyes']:pose('Face_Smile',.45,'eyes')
 elif name=='Curious':pose('Face_Smirk',.4,'eyes')
 elif name.startswith('Gaze'):
  move('MSTR-Eye_target',{'GazeRight':(.12,0,0),'GazeLeft':(-.12,0,0),'GazeUp':(0,0,.08),'GazeDown':(0,0,-.08)}[name])
 elif name=='HeadNod':r.pose.bones['FK-Head'].rotation_euler.x+=.09
 elif name in ['LookRight','LookLeft']:r.pose.bones['FK-Head'].rotation_euler.y+=-.12 if name=='LookRight' else .12
 elif name=='Breathe':r.pose.bones['FK-Spine4'].scale=(1.012,1.008,1.012)
 elif name=='Gesture':r.pose.bones['FK-UpperArm.L'].rotation_euler.z=-1.;r.pose.bones['FK-Forearm.L'].rotation_euler.x=.65
def store_pose(name,arrays=None):
 dg=update();count=0
 for src in sources:
  part=src.name.removeprefix('GEO-storm-')
  if name not in ['HeadNod','LookRight','LookLeft','Breathe','Gesture'] and part not in face_parts:continue
  a=arrays[src.name] if arrays else coords(src,dg)
  if len(a)!=len(base[src.name]):raise RuntimeError('Topology changed: '+src.name)
  if name in ['SmileLeft','SmileRight']:
   sign=1 if name.endswith('Left') else -1;side=np.clip(.5+sign*base[src.name][0::3]/.02,0,1);side=side*side*(3-2*side);a=base[src.name]+(a-base[src.name])*np.repeat(side,3)
  if np.max(np.abs(a-base[src.name]))<1e-5:continue
  key=baked[src.name].shape_key_add(name=name);key.data.foreach_set('co',a);count+=1
 stats['morphs'][name]=count
 print('MORPH',name,count,flush=True)
for name in targets:
 reset();expression(name);store_pose(name)
 if name.startswith('Emotion_'):
  dg=update();opened={src.name:coords(src,dg) for src in sources if src.name.removeprefix('GEO-storm-') in face_parts}
  blink();dg=update();arrays={src.name:base[src.name]+coords(src,dg)-opened[src.name] for src in sources if src.name in opened}
  store_pose(name.replace('Emotion_','EmotionBlink_'),arrays)
reset();dg=update()

# Retain only body deform joints. Facial/hair rig motion is already baked.
names=[b.name for b in r.data.bones if b.use_deform and (re.match(r'^DEF-(Spine[1-4]|Neck|Head|Shoulder\.|UpperArm_|Forearm_|Wrist\.|Finger|Thigh_|Knee_|Foot\.|Toes\.|PantLeg|Lace)',b.name) or 'Hair' in b.name or b.name in ['FK-Eye.L','FK-Eye.R'])]
hair=[]
for name in names:
 if 'Hair' not in name:continue
 parent=r.data.bones[name].parent
 while parent and parent.name not in names:parent=parent.parent
 hair.append({'name':name,'parent':parent.name if parent and 'Hair' in parent.name else None})
(root/'assets/avatar/models/storm-rig.json').write_text(json.dumps({'hair':hair,'eyes':['FK-Eye.L','FK-Eye.R'],'head':'DEF-Head'},indent=2))
er=r.evaluated_get(dg);rest={n:er.pose.bones[n].matrix.copy() for n in names}
arm=bpy.data.armatures.new('Storm_Runtime_Skeleton');actor=bpy.data.objects.new('Storm_Performance',arm);col.objects.link(actor);actor.matrix_world=r.matrix_world.copy()
for o in bpy.context.selected_objects:o.select_set(False)
actor.select_set(True);bpy.context.view_layer.objects.active=actor;bpy.ops.object.mode_set(mode='EDIT')
for n in names:b=arm.edit_bones.new(n);b.matrix=rest[n];b.length=max(.01,r.data.bones[n].length)
bpy.ops.object.mode_set(mode='OBJECT')
def source_weights(src,obj):
 groupnames={g.index:g.name for g in src.vertex_groups};result=[]
 for v in obj.data.vertices:
  if src.name in ['GEO-storm-eye.L','GEO-storm-eye.R','GEO-storm-eye_cornea.L','GEO-storm-eye_cornea.R']:
   result.append({'FK-Eye.'+src.name[-1]:1.});continue
  weights={}
  for g in v.groups:
   name=groupnames.get(g.group,'')
   if not name:continue
   if name in rest:target=name
   elif name.startswith(('DEF-','FK-Hair','MSTR-','P-','CTL-','STR-')):target='DEF-Head'
   else:continue
   weights[target]=weights.get(target,0)+g.weight
  result.append(weights)
 return result
body=baked['GEO-storm-body'];bodyweights=source_weights(bpy.data.objects['GEO-storm-body'],body);tree=KDTree(len(body.data.vertices))
for v in body.data.vertices:tree.insert(body.matrix_world@v.co,v.index)
tree.balance()
for src in sources:
 obj=baked[src.name];raw=source_weights(src,obj);assignments=[]
 for v,w in zip(obj.data.vertices,raw):
  if not w:
   if src.name.removeprefix('GEO-storm-') in face_parts or 'hair' in src.name:w={'DEF-Head':1.}
   else:_,i,_=tree.find(obj.matrix_world@v.co);w=bodyweights[i] or {'DEF-Spine3':1.}
  w=sorted(w.items(),key=lambda x:-x[1])[:4];total=sum(v for _,v in w);assignments.append([(n,v/total) for n,v in w])
 obj.vertex_groups.clear();groups={n:obj.vertex_groups.new(name=n) for n in names};ids=list(range(len(obj.data.vertices)))
 for g in groups.values():g.remove(ids)
 for i,w in enumerate(assignments):
  for n,v in w:groups[n].add([i],v,'REPLACE')
 mod=obj.modifiers.new('Storm Body Skin','ARMATURE');mod.object=actor;obj.parent=actor;obj.matrix_parent_inverse=actor.matrix_world.inverted()

# Reauthor the established performance on Storm's body controls, preserving
# evaluated constraints rather than copying Snow's mesh/skeleton transforms.
bodydata=None
for node in ast.parse((root/'tools/build_emotions.py').read_text()).body:
 if isinstance(node,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='body' for t in node.targets):bodydata=ast.literal_eval(node.value)
bind={n:actor.data.bones[n].matrix_local.copy() for n in names}
hidden={o:o.hide_viewport for o in bpy.context.scene.objects if o.type=='MESH'}
for o in hidden:o.hide_viewport=True
clips=[];fps=20;scene.render.fps=fps
def smooth(v):v=max(0,min(1,v));return v*v*(3-2*v)
for clip,seconds in [('Teaching_Apple_10s',10),('Emotion_Reel',72)]:
 actor.animation_data_create();actor.animation_data.action=None;previous={}
 # Smooth authored gesture curves do not need redundant rig evaluation on
 # every display frame. Preserve every teaching key and sample in between;
 # emotion envelopes use explicit attack/hold/release keys.
 times=sorted({round(i/5,4) for i in range(51)}|{t for axes in TRACKS.values() for keys in axes.values() for t,_ in keys}) if seconds==10 else [i*6+t for i in range(12) for t in [0,.2,.5,.8,1.15,1.6,2.2,3,4,4.65,5,5.35,5.7,6]]
 for frame in [t*fps for t in sorted(set(times))]:
  t=frame/fps;scene.frame_set(int(frame),subframe=frame-int(frame));reset();pose('Hand_Relax',.55)
  if clip=='Teaching_Apple_10s':
   for joint,axes in TRACKS.items():
    actual='FK-Spine4' if joint=='FK-Chest' else joint
    for axis,keys in axes.items():
     v=sample(keys,t)
     if axis==1 and joint in ['FK-Head','FK-Chest']:v=-v
     if axis==0 and joint.startswith('FK-UpperArm'):v=-v
     r.pose.bones[actual].rotation_euler[axis]=v
  else:
   e=list(emotions)[min(11,int(t/6))];local=t-min(11,int(t/6))*6;b=bodydata[e];a=smooth(local/(.55 if e in ['afraid','surprised'] else 1.15))*(1-smooth((local-4.65)/1.35))
   for joint,offset in [('FK-Head',0),('FK-Spine4',3)]:
    for axis in range(3):r.pose.bones[joint].rotation_euler[axis]+=b[offset+axis]*a
   for side,spread,bend,wrist in [('R',b[6],b[8],b[10]),('L',b[7],b[9],b[11])]:
    p=r.pose.bones['FK-UpperArm.'+side];p.rotation_euler.z+=(spread-p.rotation_euler.z)*a;p.rotation_euler.x+=.12*a
    p=r.pose.bones['FK-Forearm.'+side];p.rotation_euler.x+=(bend-p.rotation_euler.x)*a
    r.pose.bones['FK-Wrist.'+side].rotation_euler.y+=wrist*a
  dg=update();er=r.evaluated_get(dg)
  for n in names:
   p=actor.pose.bones[n];p.rotation_mode='QUATERNION';p.matrix_basis=bind[n].inverted()@er.pose.bones[n].matrix@rest[n].inverted()@bind[n]
   if n in previous and p.rotation_quaternion.dot(previous[n])<0:p.rotation_quaternion.negate()
   previous[n]=p.rotation_quaternion.copy()
   for prop in ['location','rotation_quaternion','scale']:p.keyframe_insert(data_path=prop,frame=frame,group=n)
  if frame%120==0:print('BODY',clip,frame,flush=True)
 action=actor.animation_data.action;action.name=clip;action.use_fake_user=True;clips.append(action)
 for l in action.layers:
  for s in l.strips:
   for bag in s.channelbags:
    for f in bag.fcurves:
     for k in f.keyframe_points:k.interpolation='LINEAR'
actor.animation_data.action=None
for a in clips:
 track=actor.animation_data.nla_tracks.new();track.name=a.name;strip=track.strips.new(a.name,0,a);strip.action_frame_start=0;strip.action_frame_end=10*fps if a.name.startswith('Teaching') else 72*fps
for o,v in hidden.items():o.hide_viewport=v
reset();scene.frame_set(0);update()
for o in bpy.context.selected_objects:o.select_set(False)
for o in col.objects:o.hide_render=False;o.select_set(True)
bpy.context.view_layer.objects.active=actor
scene.frame_start=0;scene.frame_end=72*fps
bpy.ops.wm.save_as_mainfile(filepath=str(out/'storm-runtime.blend'))
dest=root/'assets/avatar/models/storm-performance.glb'
bpy.ops.export_scene.gltf(filepath=str(dest),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='NLA_TRACKS',export_force_sampling=False,export_morph=True,export_morph_normal=True,export_skins=True,export_yup=True,export_cameras=False,export_lights=False)
from pack_glb import pack
stats['packing']=pack(dest,'Storm')
stats['bytes']=dest.stat().st_size;stats['joints']=len(names)
(root/'docs/storm-export.json').write_text(json.dumps(stats,indent=2));print('STORM EXPORTED',stats['bytes'],flush=True)

