"""Bake the official Snow rig to a self-contained runtime GLB with morph poses.
Run in a separate Blender background process; never touches the user's open scene.
"""
import bpy, pathlib, json, re, math, sys
import numpy as np
from mathutils import Quaternion, Vector

root=pathlib.Path(__file__).resolve().parent.parent
performance_mode='--performance' in sys.argv
out=root/'assets/avatar/models'; out.mkdir(parents=True,exist_ok=True)
rig=bpy.data.objects['RIG-Snow']
rig.animation_data.action=None
for track in rig.animation_data.nla_tracks: track.mute=True
props=rig.pose.bones['Properties']
props['ik_left_upperarm']=0.0
props['ik_right_upperarm']=0.0
rig.pose.bones['FK-UpperArm.L'].rotation_euler.z=-1.32
rig.pose.bones['FK-UpperArm.R'].rotation_euler.z=1.32
rig.pose.bones['FK-Forearm.L'].rotation_euler.x=-0.08
rig.pose.bones['FK-Forearm.R'].rotation_euler.x=-0.08
initial={p.name:(p.location.copy(),p.rotation_euler.copy(),p.rotation_quaternion.copy(),p.scale.copy()) for p in rig.pose.bones}

def reset():
    for name,(loc,rot,quat,scale) in initial.items():
        p=rig.pose.bones[name];p.location=loc;p.rotation_euler=rot;p.rotation_quaternion=quat;p.scale=scale

def curves(a):
    return [f for layer in a.layers for strip in layer.strips for bag in strip.channelbags for f in bag.fcurves]

def pose(name,amount=1.0):
    a=bpy.data.actions[name]; frame=a.frame_range[0]
    for f in curves(a):
        m=re.fullmatch(r'pose.bones\["(.+?)"\]\.(location|rotation_euler|rotation_quaternion|scale)',f.data_path)
        if not m: continue
        bone=rig.pose.bones.get(m[1])
        if not bone: continue
        arr=getattr(bone,m[2]); value=f.evaluate(frame)
        arr[f.array_index]=arr[f.array_index]+(value-arr[f.array_index])*amount

names=['body','head','shirt','pants','shoes_base','shoes_bottom','shoes_parts','hair_base','eyebrows','eye_anim','teeth_upper','teeth_lower','gums_upper','gums_lower','tongue']
sources=[bpy.data.objects['GEO-snow-'+n] for n in names]
for obj in bpy.context.scene.objects:
    if obj.type=='MESH':
        for mod in obj.modifiers:
            if mod.type=='SUBSURF':
                mod.levels=1 if obj.name in ['GEO-snow-head','GEO-snow-hair_base','GEO-snow-eyebrows','GEO-snow-shirt','GEO-snow-body','GEO-snow-eye_anim'] else 0
                mod.render_levels=mod.levels

def update():
    rig.update_tag()
    bpy.context.view_layer.update()
    return bpy.context.evaluated_depsgraph_get()

def positions(obj,dg):
    ev=obj.evaluated_get(dg);mesh=ev.to_mesh()
    a=np.empty(len(mesh.vertices)*3,dtype=np.float32);mesh.vertices.foreach_get('co',a)
    ev.to_mesh_clear();return a

reset();dg=update()
export_collection=bpy.data.collections.new('Snow_Runtime_Export');bpy.context.scene.collection.children.link(export_collection)
baked={};base={};stats={}
for obj in sources:
    mesh=bpy.data.meshes.new_from_object(obj.evaluated_get(dg),preserve_all_data_layers=True,depsgraph=dg)
    # Object-level material overrides are not guaranteed to be copied to evaluated meshes.
    mats=[s.material for s in obj.material_slots]
    material_indices=[p.material_index for p in mesh.polygons]
    mesh.materials.clear()
    for mat in mats: mesh.materials.append(mat)
    for p,material_index in zip(mesh.polygons,material_indices): p.material_index=material_index
    new=bpy.data.objects.new(obj.name.replace('GEO-snow-','Snow_'),mesh);export_collection.objects.link(new)
    new.matrix_world=obj.matrix_world.copy()
    for poly in mesh.polygons: poly.use_smooth=True
    new.shape_key_add(name='Basis')
    baked[obj.name]=new;base[obj.name]=positions(obj,dg)
    stats[new.name]={'vertices':len(mesh.vertices),'morphs':[]}

targets=[('AA','Mouth Opensmile',.60),('EE','Mouth Teethsmile',.75),('OO','Mouth Oo',.88),('UU','Mouth Uu',.85),('FF','Mouth Ff',.95),('MBP','Mouth Compressed',.45),('Smile','Mouth Teethsmile',.48),('Blink','Eyemask Closed',1.0),('BrowUp','Eyemask Scared',.30),('BrowRelax','Eyemask Relaxed',.5),('TH',None,1),('L',None,1),('HeadNod',None,1),('LookRight',None,1),('LookLeft',None,1),('Breathe',None,1),('Gesture',None,1)]
if performance_mode:
    targets += [('GazeRight',None,1),('GazeLeft',None,1),('GazeUp',None,1),('GazeDown',None,1),
                ('Warm','Eyemask Relaxed',.6),('Curious','Eyemask Cocky',.6),
                ('BrowLeft','Eyemask Scared',.65),('BrowRight','Eyemask Scared',.65),
                ('SmileLeft','Mouth Teethsmile',.55),('SmileRight','Mouth Teethsmile',.55)]
for target,action,amount in targets:
    reset()
    if action: pose(action,amount)
    if target.startswith('Gaze'):
        delta={'GazeRight':(.35,0,0),'GazeLeft':(-.35,0,0),'GazeUp':(0,0,.20),'GazeDown':(0,0,-.20)}[target]
        eye=rig.pose.bones['TGT-Eyes']
        eye.location+=eye.bone.matrix_local.to_3x3().inverted() @ Vector(delta)
    if target in ['TH','L']:
        pose('Mouth Opensmile',.24)
        # Use the actual FK controls; the old non-existent `Tongue` control
        # made TH and L identical open-mouth shapes.
        tongue_root=rig.pose.bones['FK-Tongue1']
        tongue_tip=rig.pose.bones['FK-Tongue4']
        displacement=Vector((0,-.009,.002)) if target=='TH' else Vector((0,-.002,.002))
        tongue_root.location+=tongue_root.bone.matrix_local.to_3x3().inverted() @ displacement
        if target=='L':
            tongue_tip.location+=tongue_tip.bone.matrix_local.to_3x3().inverted() @ Vector((0,-.002,.007))
    if target=='HeadNod': rig.pose.bones['FK-Head'].rotation_euler.x=.09
    if target=='LookRight': rig.pose.bones['FK-Head'].rotation_euler.y=-.12
    if target=='LookLeft': rig.pose.bones['FK-Head'].rotation_euler.y=.12
    if target=='Breathe': rig.pose.bones['FK-Chest'].scale=(1.012,1.008,1.012)
    if target=='Gesture':
        rig.pose.bones['FK-UpperArm.L'].rotation_euler.z=-.90
        rig.pose.bones['FK-Forearm.L'].rotation_euler.x=-.65
        rig.pose.bones['FK-Chest'].rotation_euler.z=-.035
    dg=update(); counts=0
    for obj in sources:
        part=obj.name.removeprefix('GEO-snow-')
        body_target=target in ['HeadNod','LookRight','LookLeft','Breathe','Gesture']
        face_parts={'head','teeth_upper','teeth_lower','gums_upper','gums_lower','tongue'}
        if target=='Blink': face_parts={'head','eyebrows','eye_anim'}
        if target in ['BrowUp','BrowRelax']: face_parts={'head','eyebrows'}
        if target in ['Warm','Curious','BrowLeft','BrowRight']:face_parts={'head','eyebrows','eye_anim'}
        if target.startswith('Gaze'):face_parts={'head','eye_anim'}
        if not body_target and part not in face_parts: continue
        a=positions(obj,dg)
        if target in ['BrowLeft','BrowRight','SmileLeft','SmileRight']:
            # Feather the facial delta around the center line; no hard seam.
            sign=1 if target.endswith('Left') else -1
            side=np.clip(.5+sign*base[obj.name][0::3]/.025,0,1)
            side=side*side*(3-2*side)
            a=base[obj.name]+(a-base[obj.name])*np.repeat(side,3)
        if len(a)!=len(base[obj.name]):raise RuntimeError('Topology changed: '+obj.name)
        delta=float(np.max(np.abs(a-base[obj.name])))
        if delta<1e-5:continue
        key=baked[obj.name].shape_key_add(name=target);key.data.foreach_set('co',a)
        stats[baked[obj.name].name]['morphs'].append({'name':target,'max_delta':round(delta,5)})
        counts+=1
    print('BAKED',target,counts,flush=True)

# Runtime materials use the original base-color images; no unsupported shader nodes.
colors={'snow.skin':(.72,.45,.30,1),'snow.skin_darker':(.12,.045,.025,1),'snow.skin_upper_lip':(.16,.055,.035,1),'snow.skin_lower_lip':(.22,.09,.055,1),'snow.gums':(.30,.07,.08,1),'snow.teeth':(.88,.84,.73,1),'snow.tongue':(.35,.09,.10,1),'snow.eyes_white':(.88,.90,.91,1),'snow.eyes_iris':(.11,.24,.30,1),'snow.eyes_pupil':(.004,.006,.009,1)}
maps={'snow.skin':'skin_atlas','snow.hair':'hair_diffuse','snow.shirt':'shirt_diffuse','snow.pants':'pants_diffuse','snow.shoe':'shoes_diffuse'}
runtime_mats={}
for obj in sources:
    new=baked[obj.name]
    for slot in new.material_slots:
        if not slot.material:continue
        name=slot.material.name
        if name not in runtime_mats:
            m=bpy.data.materials.new('Runtime_'+name);m.use_nodes=True
            bsdf=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED');bsdf.inputs['Base Color'].default_value=colors.get(name,(.2,.12,.08,1));bsdf.inputs['Roughness'].default_value=.63
            if name=='snow.eyes_pupil':bsdf.inputs['Roughness'].default_value=.18
            if name=='snow.eyes_iris':bsdf.inputs['Roughness'].default_value=.28
            if name in maps:
                tex=m.node_tree.nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(root/'work/textures'/f'{maps[name]}.jpg'),check_existing=True)
                m.node_tree.links.new(tex.outputs['Color'],bsdf.inputs['Base Color'])
            runtime_mats[name]=m
        slot.material=runtime_mats[name]
    # Convert three UDIM skin tiles to a single glTF-compatible atlas.
    uv=new.data.uv_layers.active
    if uv:
        for poly in new.data.polygons:
            mat=new.material_slots[poly.material_index].material
            if mat and mat.name=='Runtime_snow.skin':
                for idx in poly.loop_indices: uv.data[idx].uv.x/=3
        for layer in new.data.uv_layers:
            if layer!=uv:
                for item in layer.data: item.uv.x/=3

reset();update()
actor=None
if performance_mode:
    sys.path.insert(0,str(root/'tools'))
    from performance_skeleton import add_performance
    actor,performance_stats=add_performance(rig,sources,baked,export_collection,reset,update)
    (root/'docs/performance-animation.json').write_text(json.dumps(performance_stats,indent=2))
for obj in bpy.context.selected_objects:obj.select_set(False)
for new in baked.values():new.select_set(True)
if actor:actor.select_set(True)
bpy.context.view_layer.objects.active=list(baked.values())[0]
path=out/('snow-performance.glb' if performance_mode else 'snow.glb')
if performance_mode:bpy.ops.wm.save_as_mainfile(filepath=str(root/'work/performance-baked.blend'))
bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_animations=performance_mode,export_animation_mode='ACTIVE_ACTIONS',export_nla_strips_merged_animation_name='Teaching_Apple_10s',export_morph=True,export_morph_normal=True,export_morph_tangent=False,export_skins=performance_mode,export_yup=True,export_cameras=False,export_lights=False)
stats['file_bytes']=path.stat().st_size
import sys
sys.path.insert(0,str(root/'tools'))
from pack_glb import pack
packing=pack(path)
(root/('docs/performance-model-packing.json' if performance_mode else 'docs/model-packing.json')).write_text(json.dumps(packing,indent=2),encoding='utf8')
stats['file_bytes']=path.stat().st_size
(root/('docs/performance-model-report.json' if performance_mode else 'docs/model-report.json')).write_text(json.dumps(stats,indent=2),encoding='utf8')
print('EXPORTED',path,stats['file_bytes'],flush=True)
