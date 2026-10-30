"""Replace Snow's viewport proxy with the official render eyes and corneas.

Run in background Blender against work/performance-expressive.blend.
Keeps the body clip and authored face; bakes eye gaze from the original rig.
"""
import bpy, pathlib, sys, json, re
import numpy as np
from mathutils import Vector
root=pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0,str(root/'tools'))
from pack_glb import pack
r=bpy.data.objects['RIG-Snow'];actor=bpy.data.objects['Snow_Performance']
collection=bpy.data.collections['Snow_Runtime_Export']
initial={p.name:(p.location.copy(),p.rotation_euler.copy(),p.rotation_quaternion.copy(),p.scale.copy()) for p in r.pose.bones}
def reset():
 for name,(loc,rot,quat,scale) in initial.items():
  p=r.pose.bones[name];p.location=loc;p.rotation_euler=rot;p.rotation_quaternion=quat;p.scale=scale
def update():
 r.update_tag();bpy.context.view_layer.update();return bpy.context.evaluated_depsgraph_get()
def pose(name,amount):
 a=bpy.data.actions[name]
 for layer in a.layers:
  for strip in layer.strips:
   for bag in strip.channelbags:
    for f in bag.fcurves:
     m=re.fullmatch(r'pose.bones\["(.+?)"\]\.(location|rotation_euler|rotation_quaternion|scale)',f.data_path)
     if m and r.pose.bones.get(m[1]):
      arr=getattr(r.pose.bones[m[1]],m[2]);arr[f.array_index]+=(f.evaluate(a.frame_range[0])-arr[f.array_index])*amount
def coords(source,dg):
 ev=source.evaluated_get(dg);mesh=ev.to_mesh()
 a=np.empty(len(mesh.vertices)*3,dtype=np.float32);mesh.vertices.foreach_get('co',a);ev.to_mesh_clear();return a

sources=[bpy.data.objects['GEO-snow-eyes'],bpy.data.objects['GEO-snow_eye_corneas']]
for source in sources:
 source.hide_viewport=False;source.hide_set(False)
 for mod in source.modifiers:
  if mod.type=='SUBSURF':mod.levels=1;mod.render_levels=1
reset();dg=update();baked={};base={}
for source,name in zip(sources,['Snow_eyes','Snow_corneas']):
 mesh=bpy.data.meshes.new_from_object(source.evaluated_get(dg),preserve_all_data_layers=True,depsgraph=dg)
 mesh.materials.clear()
 obj=bpy.data.objects.new(name,mesh);collection.objects.link(obj);obj.matrix_world=source.matrix_world.copy()
 for poly in mesh.polygons:poly.use_smooth=True
 obj.shape_key_add(name='Basis');baked[name]=obj;base[name]=coords(source,dg)
 # Both original eyes deform rigidly with the head; eye rotation and lid
 # lattice changes are sampled below into the existing runtime morph system.
 obj.vertex_groups.clear();g=obj.vertex_groups.new(name='DEF-Head')
 g.add(list(range(len(mesh.vertices))),1,'REPLACE')
 mod=obj.modifiers.new('Performance Skin','ARMATURE');mod.object=actor
 obj.parent=actor;obj.matrix_parent_inverse=actor.matrix_world.inverted()

targets=['GazeRight','GazeLeft','GazeUp','GazeDown','Blink','Warm','Curious','HeadNod','LookRight','LookLeft','Breathe','Gesture','SmileEyes','Attentive']
deltas={}
for target in targets:
 reset()
 if target.startswith('Gaze'):
  delta={'GazeRight':(.35,0,0),'GazeLeft':(-.35,0,0),'GazeUp':(0,0,.20),'GazeDown':(0,0,-.20)}[target]
  eye=r.pose.bones['TGT-Eyes'];eye.location+=eye.bone.matrix_local.to_3x3().inverted() @ Vector(delta)
 if target in ['Blink','Warm','Curious']:
  action,amount={'Blink':('Eyemask Closed',1),'Warm':('Eyemask Relaxed',.6),'Curious':('Eyemask Cocky',1)}[target];pose(action,amount)
 if target=='HeadNod':r.pose.bones['FK-Head'].rotation_euler.x=.09
 if target=='LookRight':r.pose.bones['FK-Head'].rotation_euler.y=-.12
 if target=='LookLeft':r.pose.bones['FK-Head'].rotation_euler.y=.12
 if target=='Breathe':r.pose.bones['FK-Chest'].scale=(1.012,1.008,1.012)
 if target=='Gesture':
  r.pose.bones['FK-UpperArm.L'].rotation_euler.z=-.90;r.pose.bones['FK-Forearm.L'].rotation_euler.x=-.65;r.pose.bones['FK-Chest'].rotation_euler.z=-.035
 if target in ['SmileEyes','Attentive']:
  for side in ['L','R']:
   if target=='SmileEyes':
    for bone,value in [('CheekRaiser',.006),('CenterCheekRaiser',.004),('InnerCheekRaiser',.002),('MSTR-Eyelid_Lower',.004),('MSTR-Eyelid_Upper',-.005)]:r.pose.bones[bone+'.'+side].location.y=value
   else:r.pose.bones['MSTR-Eyelid_Upper.'+side].location.y=.0025
 dg=update()
 for source,(name,obj) in zip(sources,baked.items()):
  a=coords(source,dg);delta=float(np.max(np.abs(a-base[name])))
  if delta<1e-5:continue
  obj.shape_key_add(name=target).data.foreach_set('co',a);deltas[name+'_'+target]=delta
reset();update()

def material(name):
 m=bpy.data.materials.new(name);m.use_nodes=True
 return m,next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
def texture(m,filename,color_space):
 n=m.node_tree.nodes.new('ShaderNodeTexImage')
 n.image=bpy.data.images.load(str(root/'source-models/snow-source/Snow/textures'/filename),check_existing=False)
 n.image.colorspace_settings.name=color_space
 # The eye fills only a small part of the viewport; retain original artwork,
 # reduced to 1024 for diffuse and 512 for surface detail.
 size=1024 if filename=='eyes_diffuse.png' else 512
 n.image.scale(size,size);n.image.pack();return n
m,p=material('Runtime_snow.eyes');p.inputs['Roughness'].default_value=.32;p.inputs['Metallic'].default_value=0
diffuse=texture(m,'eyes_diffuse.png','sRGB');m.node_tree.links.new(diffuse.outputs['Color'],p.inputs['Base Color'])
normal=texture(m,'eyes_normal.png','Non-Color');n=m.node_tree.nodes.new('ShaderNodeNormalMap');n.inputs['Strength'].default_value=.65
m.node_tree.links.new(normal.outputs['Color'],n.inputs['Color']);m.node_tree.links.new(n.outputs['Normal'],p.inputs['Normal'])
baked['Snow_eyes'].data.materials.append(m)
m,p=material('Runtime_snow.eyes_cornea');p.inputs['Base Color'].default_value=(1,1,1,1)
p.inputs['Roughness'].default_value=.035;p.inputs['IOR'].default_value=1.376;p.inputs['Transmission Weight'].default_value=1
baked['Snow_corneas'].data.materials.append(m)
proxy=bpy.data.objects.get('Snow_eye_anim')
if proxy:
 for c in list(proxy.users_collection):c.objects.unlink(proxy)

for obj in bpy.context.selected_objects:obj.select_set(False)
for obj in collection.objects:obj.select_set(True)
bpy.context.view_layer.objects.active=actor
path=root/'assets/avatar/models/snow-performance.glb'
bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='ACTIVE_ACTIONS',export_nla_strips_merged_animation_name='Teaching_Apple_10s',export_morph=True,export_morph_normal=True,export_skins=True,export_cameras=False,export_lights=False)
report={'source_meshes':[s.name for s in sources],'removed_proxy':'Snow_eye_anim','deltas':deltas,'packing':pack(path)}
(root/'docs/eye-restoration-report.json').write_text(json.dumps(report,indent=2))
bpy.ops.wm.save_as_mainfile(filepath=str(root/'work/performance-render-eyes.blend'))
print('RESTORED_RENDER_EYES',json.dumps(report),flush=True)
