"""Read-only source-rig audit in a separate background Blender process."""
import bpy,json,pathlib,math
from mathutils import Vector
root=pathlib.Path(__file__).resolve().parents[1]
rig=bpy.data.objects['RIG-storm']
if rig.animation_data:
    rig.animation_data.action=None
    for track in rig.animation_data.nla_tracks: track.mute=True
rig.pose.bones['Properties_Character_Storm']['Anim Eyes']=False
rig.update_tag();bpy.context.view_layer.update()
dg=bpy.context.evaluated_depsgraph_get();evaluated_rig=rig.evaluated_get(dg)
result={'targets':{},'eyes':[]}
for name in ['MSTR-Eye_target','TGT-Eyes','FK-Eye.L','FK-Eye.R','DEF-Head']:
    bone=evaluated_rig.pose.bones.get(name)
    if bone:result['targets'][name]={'position':list(rig.matrix_world@bone.matrix.translation),'matrix':[list(row) for row in bone.matrix]}
for side in ['L','R']:
    obj=bpy.data.objects['GEO-storm-eye.'+side]
    evaluated=obj.evaluated_get(dg);mesh=evaluated.to_mesh()
    center=rig.matrix_world@evaluated_rig.pose.bones['FK-Eye.'+side].matrix.translation
    groups={}
    for polygon in mesh.polygons:
        name=mesh.materials[polygon.material_index].name
        if 'pupil' not in name and 'iris' not in name:continue
        part=groups.setdefault(name,{'center':Vector(), 'area':0,'polygons':0})
        part['center']+=(evaluated.matrix_world@polygon.center)*polygon.area
        part['area']+=polygon.area;part['polygons']+=1
    parts={}
    for name,part in groups.items():
        p=part['center']/part['area'];direction=(p-center).normalized()
        parts[name]={'centroid':list(p),'direction':list(direction),'yawDegrees':math.degrees(math.atan2(direction.x,-direction.y)),'polygons':part['polygons']}
    result['eyes'].append({'side':side,'center':list(center),'materials':parts})
    evaluated.to_mesh_clear()
(root/'work/storm-eye-source-axes.json').write_text(json.dumps(result,indent=2))
print('EYE_SOURCE_AUDIT',json.dumps(result),flush=True)

if '--render' in __import__('sys').argv:
    def render(name):
        scene=bpy.context.scene
        for obj in list(scene.objects):
            if obj.type in ['LIGHT','CAMERA']:bpy.data.objects.remove(obj,do_unlink=True)
        camera=bpy.data.objects.new('EyeAuditCamera',bpy.data.cameras.new('EyeAuditCamera'))
        scene.collection.objects.link(camera);camera.location=(0,-2,1.08)
        camera.rotation_euler=(Vector((0,0,1.08))-camera.location).to_track_quat('-Z','Y').to_euler()
        camera.data.type='ORTHO';camera.data.ortho_scale=.45;scene.camera=camera
        for label,position,energy in [('Key',(-2,-3,3),300),('Fill',(2,-3,2),150)]:
            light=bpy.data.objects.new(label,bpy.data.lights.new(label,'AREA'))
            scene.collection.objects.link(light);light.location=position;light.data.energy=energy;light.data.shape='DISK';light.data.size=3
            light.rotation_euler=(Vector((0,0,1.08))-light.location).to_track_quat('-Z','Y').to_euler()
        scene.world=bpy.data.worlds.new('EyeAuditWorld');scene.world.use_nodes=True
        background=scene.world.node_tree.nodes.new('ShaderNodeBackground')
        output=scene.world.node_tree.nodes.new('ShaderNodeOutputWorld')
        scene.world.node_tree.links.new(background.outputs[0],output.inputs['Surface'])
        background.inputs['Color'].default_value=(.15,.15,.15,1)
        background.inputs['Strength'].default_value=.4
        scene.render.engine='CYCLES';scene.cycles.samples=12;scene.cycles.use_denoising=True
        scene.render.resolution_x=800;scene.render.resolution_y=700;scene.render.resolution_percentage=100
        scene.render.image_settings.file_format='PNG';scene.render.filepath=str(root/'outputs/flutter-scene'/name)
        bpy.ops.render.render(write_still=True)
    render('source-eyes-orthographic.png')
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(root/'assets/avatar/models/storm-performance.glb'))
    for obj in bpy.context.scene.objects:
        if obj.animation_data:
            obj.animation_data.action=None
            for track in obj.animation_data.nla_tracks:track.mute=True
        if obj.type=='MESH' and obj.data.shape_keys:
            obj.data.shape_keys.animation_data_clear()
            for key in obj.data.shape_keys.key_blocks:key.value=0
    render('glb-eyes-orthographic.png')
    for amount in [.35,.6]:
        for obj in bpy.context.scene.objects:
            if obj.type!='MESH' or not obj.data.shape_keys:continue
            keys=obj.data.shape_keys.key_blocks
            if 'GazeRight' not in keys or 'GazeLeft' not in keys:continue
            neutral=keys.get('NeutralCalibration') or obj.shape_key_add(name='NeutralCalibration')
            basis=keys[0]
            for i,vertex in enumerate(neutral.data):
                target=keys['GazeRight' if basis.data[i].co.x>=0 else 'GazeLeft']
                vertex.co=basis.data[i].co+(target.data[i].co-basis.data[i].co)*amount
            neutral.value=1
        bpy.context.view_layer.update()
        render('glb-eyes-calibrated-'+str(amount)+'.png')
