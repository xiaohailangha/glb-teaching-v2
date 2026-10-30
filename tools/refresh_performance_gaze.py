import bpy,pathlib,sys,numpy as np,json
from mathutils import Vector
root=pathlib.Path(__file__).resolve().parents[1];sys.path.insert(0,str(root/'tools'))
from pack_glb import pack
r=bpy.data.objects['RIG-Snow'];p=r.pose.bones['TGT-Eyes'];initial=p.location.copy();report={}
for name,delta in {'GazeRight':(.35,0,0),'GazeLeft':(-.35,0,0),'GazeUp':(0,0,.20),'GazeDown':(0,0,-.20)}.items():
 p.location=initial+p.bone.matrix_local.to_3x3().inverted() @ Vector(delta)
 r.update_tag();bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get()
 for part in ['head','eye_anim']:
  source=bpy.data.objects['GEO-snow-'+part];dest=bpy.data.objects['Snow_'+part]
  ev=source.evaluated_get(dg);mesh=ev.to_mesh();a=np.empty(len(mesh.vertices)*3,dtype=np.float32);mesh.vertices.foreach_get('co',a);ev.to_mesh_clear()
  key=dest.data.shape_keys.key_blocks.get(name) or dest.shape_key_add(name=name);key.data.foreach_set('co',a)
  base=np.empty(len(a),dtype=np.float32);dest.data.shape_keys.key_blocks['Basis'].data.foreach_get('co',base)
  report[part+'_'+name]=float(np.max(np.abs(a-base)))
p.location=initial;r.update_tag();bpy.context.view_layer.update()
for obj in bpy.context.selected_objects:obj.select_set(False)
for obj in bpy.data.collections['Snow_Runtime_Export'].objects:obj.select_set(True)
bpy.context.view_layer.objects.active=bpy.data.objects['Snow_Performance']
path=root/'assets/avatar/models/snow-performance.glb'
bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='ACTIVE_ACTIONS',export_nla_strips_merged_animation_name='Teaching_Apple_10s',export_morph=True,export_morph_normal=True,export_skins=True,export_cameras=False,export_lights=False)
packing=pack(path)
(root/'docs/performance-gaze.json').write_text(json.dumps(report,indent=2))
(root/'docs/performance-model-packing.json').write_text(json.dumps(packing,indent=2))
print(report,packing)
bpy.ops.wm.save_as_mainfile(filepath=str(root/'work/performance-final.blend'))
