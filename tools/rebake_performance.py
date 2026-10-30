"""Iterate authored acting from the saved export scene without touching live Blender."""
import bpy,pathlib,sys,json
root=pathlib.Path(__file__).resolve().parents[1];sys.path.insert(0,str(root/'tools'))
from performance_skeleton import bake_clip
from pack_glb import pack
r=bpy.data.objects['RIG-Snow'];actor=bpy.data.objects['Snow_Performance']
initial={p.name:(p.location.copy(),p.rotation_euler.copy(),p.rotation_quaternion.copy(),p.scale.copy()) for p in r.pose.bones}
def reset():
 for name,(loc,rot,quat,scale) in initial.items():
  p=r.pose.bones[name];p.location=loc;p.rotation_euler=rot;p.rotation_quaternion=quat;p.scale=scale
def update():
 r.update_tag();bpy.context.view_layer.update();return bpy.context.evaluated_depsgraph_get()
reset();dg=update();er=r.evaluated_get(dg)
rest={b.name:er.pose.bones[b.name].matrix.copy() for b in actor.data.bones}
bake_clip(r,actor,rest,reset,update)
# Give the shirt a 3 mm clearance over the skinned torso, consistently across
# all morphs. Avoid duplicated inflation if re-running this helper.
shirt=bpy.data.objects['Snow_shirt']
if not shirt.get('performance_clearance'):
 for vertex in shirt.data.vertices:
  delta=vertex.normal*.003
  for key in shirt.data.shape_keys.key_blocks:key.data[vertex.index].co+=delta
 shirt['performance_clearance']=True
for obj in bpy.context.selected_objects:obj.select_set(False)
for obj in bpy.data.collections['Snow_Runtime_Export'].objects:obj.select_set(True)
bpy.context.view_layer.objects.active=actor
path=root/'assets/avatar/models/snow-performance.glb'
bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='ACTIVE_ACTIONS',export_nla_strips_merged_animation_name='Teaching_Apple_10s',export_morph=True,export_morph_normal=True,export_skins=True,export_cameras=False,export_lights=False)
print(pack(path))
bpy.ops.wm.save_as_mainfile(filepath=str(root/'work/performance-refined.blend'))
