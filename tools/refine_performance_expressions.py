"""Rebuild readable facial acting from Snow's original face controls.

Run against work/performance-refined.blend in a separate background Blender.
Preserves the skeletal performance; replaces weak/symmetrical face poses.
"""
import bpy,pathlib,sys,json,re,numpy as np
root=pathlib.Path(__file__).resolve().parents[1];sys.path.insert(0,str(root/'tools'))
from pack_glb import pack
r=bpy.data.objects['RIG-Snow']
initial={p.name:(p.location.copy(),p.rotation_euler.copy(),p.rotation_quaternion.copy(),p.scale.copy()) for p in r.pose.bones}
def reset():
 for name,(loc,rot,quat,scale) in initial.items():
  p=r.pose.bones[name];p.location=loc;p.rotation_euler=rot;p.rotation_quaternion=quat;p.scale=scale
def pose(name,amount=1):
 a=bpy.data.actions[name]
 for layer in a.layers:
  for strip in layer.strips:
   for bag in strip.channelbags:
    for f in bag.fcurves:
     m=re.fullmatch(r'pose.bones\["(.+?)"\]\.(location|rotation_euler|rotation_quaternion|scale)',f.data_path)
     if m and r.pose.bones.get(m[1]):
      arr=getattr(r.pose.bones[m[1]],m[2]);arr[f.array_index]+=(f.evaluate(a.frame_range[0])-arr[f.array_index])*amount
report={}
for target in ['SmileLeft','SmileRight','SmileEyes','BrowLeft','BrowRight','Curious','Attentive']:
 reset()
 if target.startswith('Smile') and target!='SmileEyes':pose('Mouth Teethsmile',1.05)
 if target=='Curious':pose('Eyemask Cocky',1)
 if target in ['SmileEyes','Attentive']:
  for side in ['L','R']:
   if target=='SmileEyes':
    r.pose.bones['CheekRaiser.'+side].location.y=.006
    r.pose.bones['CenterCheekRaiser.'+side].location.y=.004
    r.pose.bones['InnerCheekRaiser.'+side].location.y=.002
    r.pose.bones['MSTR-Eyelid_Lower.'+side].location.y=.004
    r.pose.bones['MSTR-Eyelid_Upper.'+side].location.y=-.005
   else:
    r.pose.bones['MSTR-Eyelid_Upper.'+side].location.y=.0025
 if target.startswith('Brow'):
  side='L' if target=='BrowLeft' else 'R'
  r.pose.bones['MSTR-Eyebrow.'+side].location.y=.028
  r.pose.bones['MSTR-Eyebrow.'+side].location.x=-.003 if side=='L' else .003
 r.update_tag();bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get()
 parts=['head','eyebrows','eye_anim','teeth_upper','teeth_lower','gums_upper','gums_lower','tongue'] if target.startswith('Smile') else ['head','eyebrows','eye_anim']
 for part in parts:
  source=bpy.data.objects['GEO-snow-'+part];dest=bpy.data.objects['Snow_'+part]
  ev=source.evaluated_get(dg);mesh=ev.to_mesh();a=np.empty(len(mesh.vertices)*3,dtype=np.float32);mesh.vertices.foreach_get('co',a);ev.to_mesh_clear()
  base=np.empty(len(a),dtype=np.float32);dest.data.shape_keys.key_blocks['Basis'].data.foreach_get('co',base)
  if target in ['SmileLeft','SmileRight']:
   sign=1 if target.endswith('Left') else -1
   side=np.clip(.5+sign*base[0::3]/.025,0,1);side=side*side*(3-2*side)
   a=base+(a-base)*np.repeat(side,3)
  delta=float(np.max(np.abs(a-base)))
  existing=dest.data.shape_keys.key_blocks.get(target)
  if delta<1e-5 and not existing:continue
  key=existing or dest.shape_key_add(name=target);key.data.foreach_set('co',a)
  report[part+'_'+target]=delta
reset();r.update_tag();bpy.context.view_layer.update()
for obj in bpy.context.selected_objects:obj.select_set(False)
for obj in bpy.data.collections['Snow_Runtime_Export'].objects:obj.select_set(True)
bpy.context.view_layer.objects.active=bpy.data.objects['Snow_Performance']
path=root/'assets/avatar/models/snow-performance.glb'
bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='ACTIVE_ACTIONS',export_nla_strips_merged_animation_name='Teaching_Apple_10s',export_morph=True,export_morph_normal=True,export_skins=True,export_cameras=False,export_lights=False)
packing=pack(path)
(root/'docs/expression-model-report.json').write_text(json.dumps({'deltas':report,'packing':packing},indent=2))
bpy.ops.wm.save_as_mainfile(filepath=str(root/'work/performance-expressive.blend'))
print(report,packing)
# The intermediate scene retains the proxy for editing; the shipped asset must
# always replace it with Snow's render eyes and corneas after facial rebaking.
import runpy
runpy.run_path(str(root/'tools/restore_render_eyes.py'),run_name='__main__')
