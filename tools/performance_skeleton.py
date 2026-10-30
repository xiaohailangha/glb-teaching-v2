"""Bake an authored ten-second performance from Snow's original control rig.

Runtime joints use the evaluated relaxed pose as their bind pose. Facial groups
are consolidated onto the head; expressions remain independent morph targets.
Each runtime joint is a root with sampled world-space transforms. This preserves
the source rig's constrained body motion without exporting Blender constraints.
"""
import bpy, math, re
from mathutils import Vector

def sample(keys,t):
    if t<=keys[0][0]:return keys[0][1]
    for (a,x),(b,y) in zip(keys,keys[1:]):
        if t<=b:
            u=(t-a)/(b-a);u=u*u*(3-2*u)
            return x+(y-x)*u
    return keys[-1][1]

# Purposeful asymmetry: attention, greeting, presentation, two speech accents,
# an open-handed invitation, then an attentive listening pose and warm release.
TRACKS={
 'FK-Head':{
  0:[(0,-.02),(.55,-.065),(1,.035),(1.35,-.015),(2.3,-.025),(3.15,-.08),(3.65,.07),(4,-.02),(4.55,.055),(5.05,-.06),(5.7,-.01),(6.4,-.055),(7.25,.035),(8.2,.015),(8.8,-.035),(9.3,.035),(10,-.02)],
  1:[(0,-.07),(.5,.015),(1.4,.015),(1.95,-.30),(2.6,-.30),(3.15,.045),(4.1,.025),(5,-.035),(5.7,.035),(6.4,-.07),(7.1,.025),(8.6,.04),(9.5,-.03),(10,-.07)],
  2:[(0,-.035),(.7,.055),(1.5,.025),(2.3,-.045),(3.3,.035),(4.6,-.035),(5.3,.03),(6.6,-.07),(8.1,-.06),(9.3,.045),(10,-.035)]},
 'FK-Chest':{
  0:[(0,-.015),(.65,-.045),(1.4,-.01),(2.4,.025),(3.3,-.025),(4.5,-.055),(5.2,-.015),(6.4,-.035),(7.2,-.075),(8.4,-.07),(9.4,-.01),(10,-.015)],
  1:[(0,.025),(.9,-.025),(1.7,-.035),(2.4,-.12),(3.4,.025),(4.7,-.025),(5.5,.02),(6.5,-.055),(7.4,.035),(9.3,.025),(10,.025)],
  2:[(0,-.018),(.8,.035),(1.5,.01),(2.5,-.035),(3.5,.018),(4.7,.03),(5.3,-.015),(6.7,-.035),(8,-.025),(9.2,.02),(10,-.018)]},
 'FK-UpperArm.R':{
  2:[(0,1.32),(.4,1.25),(.85,.93),(1.3,.96),(1.8,1.15),(2.4,1.25),(4.2,1.15),(4.7,1.03),(5.3,1.25),(6.3,1.18),(7.5,1.30),(10,1.32)],
  0:[(0,0),(.8,-.30),(1.4,-.28),(2.2,0),(4.6,-.12),(5.4,0),(10,0)]},
 'FK-Forearm.R':{0:[(0,-.08),(.85,2.2),(1.35,2.05),(2.1,.15),(4,.25),(4.6,1.1),(5.4,.15),(6.5,.32),(7.4,.12),(10,-.08)],2:[(0,0),(.85,-.35),(1.4,-.3),(2.1,0),(4.6,-.18),(5.5,0),(10,0)]},
 'FK-Wrist.R':{2:[(0,0),(.75,.1),(.95,-.18),(1.13,.16),(1.35,-.08),(1.8,0),(10,0)]},
 'FK-UpperArm.L':{
  2:[(0,-1.32),(1.4,-1.3),(2.1,-1.0),(2.8,-1.03),(3.5,-1.15),(4.2,-1.05),(4.75,-.97),(5.4,-1.15),(6.15,-1.0),(6.8,-1.05),(7.6,-1.15),(8.8,-1.28),(10,-1.32)],
  0:[(0,0),(1.5,-.03),(2.2,-.20),(3,-.22),(3.7,-.08),(4.7,-.18),(5.5,-.1),(6.5,-.30),(7.8,-.05),(10,0)]},
 'FK-Forearm.L':{0:[(0,-.08),(1.4,.12),(2.2,1.8),(2.8,1.65),(3.5,1.2),(4.7,1.8),(5.3,1.1),(6.4,1.95),(7.1,1.7),(8,.22),(10,-.08)],2:[(0,0),(1.4,0),(2.2,.38),(3.2,.32),(4.7,.30),(5.5,.24),(6.5,.35),(7.4,.3),(8.5,0),(10,0)]},
 'FK-Wrist.L':{1:[(0,0),(1.4,0),(2.1,-.65),(3.2,-.55),(4.8,-.35),(5.3,-.25),(6.3,-.72),(7.3,-.6),(8.4,0),(10,0)]},
}

def add_performance(rig,sources,baked,collection,reset,update):
    reset();dg=update();evaluated=rig.evaluated_get(dg)
    pattern=r'^DEF-(Neck|Head|Shoulder\.|Finger_|UpperArm_|Forearm_|Wrist\.|Spine$|RibCage$|Chest$|Hips|Thigh_|Knee_|Foot\.|Toes\.|Ponytail|Hip_Center)'
    names=[b.name for b in rig.data.bones if b.use_deform and re.match(pattern,b.name)]
    rest={name:evaluated.pose.bones[name].matrix.copy() for name in names}
    arm=bpy.data.armatures.new('Snow_Performance_Skeleton')
    actor=bpy.data.objects.new('Snow_Performance',arm);collection.objects.link(actor)
    actor.matrix_world=rig.matrix_world.copy()
    for o in bpy.context.selected_objects:o.select_set(False)
    actor.select_set(True);bpy.context.view_layer.objects.active=actor
    bpy.ops.object.mode_set(mode='EDIT')
    for name in names:
        b=arm.edit_bones.new(name);b.matrix=rest[name];b.length=max(.01,rig.data.bones[name].length)
    bpy.ops.object.mode_set(mode='OBJECT')
    bound=0
    for source in sources:
        obj=baked[source.name]
        # Mesh deform indices survive evaluated subdivision/masking. Preserve
        # their association before replacing the source vertex-group table.
        source_names={g.index:g.name for g in source.vertex_groups}
        assignments=[]
        for vertex in obj.data.vertices:
            weights={}
            for group in vertex.groups:
                name=source_names.get(group.group,'')
                if not name.startswith('DEF-'):continue
                target=name if name in rest else 'DEF-Head'
                weights[target]=weights.get(target,0)+group.weight
            if not weights:weights={'DEF-Head':1} if source.name not in ['GEO-snow-pants','GEO-snow-shoes_base','GEO-snow-shoes_bottom','GEO-snow-shoes_parts'] else {'DEF-Hips':1}
            weights=sorted(weights.items(),key=lambda x:-x[1])[:4]
            total=sum(w for _,w in weights)
            assignments.append([(n,w/total) for n,w in weights])
        obj.vertex_groups.clear()
        groups={name:obj.vertex_groups.new(name=name) for name in names}
        # Clear copied deform entries before assigning the new table.
        ids=list(range(len(obj.data.vertices)))
        for group in groups.values():group.remove(ids)
        for index,weights in enumerate(assignments):
            for name,weight in weights:groups[name].add([index],weight,'REPLACE')
        mod=obj.modifiers.new('Performance Skin','ARMATURE');mod.object=actor
        obj.parent=actor;obj.matrix_parent_inverse=actor.matrix_world.inverted()
        bound+=len(assignments)
    bake_clip(rig,actor,rest,reset,update)
    return actor,{'joints':len(names),'weighted_vertices':bound,'clip':'Teaching_Apple_10s','seconds':10,'sample_rate':30}

def bake_clip(rig,actor,rest,reset,update):
    names=list(rest)
    bind={name:actor.data.bones[name].matrix_local.copy() for name in names}
    if actor.animation_data:actor.animation_data.action=None
    # Sampling joints does not need to evaluate both high-resolution source
    # geometry and runtime geometry at every frame.
    hidden={o:o.hide_viewport for o in bpy.context.scene.objects if o.type=='MESH'}
    for o in hidden:o.hide_viewport=True
    bpy.context.scene.render.fps=30;bpy.context.scene.frame_start=0;bpy.context.scene.frame_end=300
    previous_quats={}
    relaxed=[]
    for layer in bpy.data.actions['Hand Relaxed'].layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for f in bag.fcurves:
                    m=re.fullmatch(r'pose.bones\["(.+?)"\]\.(location|rotation_euler|rotation_quaternion|scale)',f.data_path)
                    if m and 'Finger' in m[1]:relaxed.append((m[1],m[2],f.array_index,f.evaluate(10)))
    for frame in range(301):
        t=frame/30
        bpy.context.scene.frame_set(frame);reset()
        for name,prop,index,value in relaxed:
            arr=getattr(rig.pose.bones[name],prop);arr[index]+=(value-arr[index])*.65
        for name,axes in TRACKS.items():
            for axis,keys in axes.items():
                value=sample(keys,t)
                if axis==1 and name in ['FK-Head','FK-Chest']:value=-value
                if axis==0 and name.startswith('FK-UpperArm'):value=-value
                rig.pose.bones[name].rotation_euler[axis]=value
        # A slight breath runs through the chest throughout speech and listening.
        rig.pose.bones['FK-Chest'].rotation_euler.x+=.005*math.sin(t*2.1)
        dg=update();evaluated=rig.evaluated_get(dg)
        for name in names:
            p=actor.pose.bones[name];p.rotation_mode='QUATERNION'
            p.matrix_basis=bind[name].inverted() @ evaluated.pose.bones[name].matrix @ rest[name].inverted() @ bind[name]
            if name in previous_quats and p.rotation_quaternion.dot(previous_quats[name])<0:p.rotation_quaternion.negate()
            previous_quats[name]=p.rotation_quaternion.copy()
            for prop in ['location','rotation_quaternion','scale']:p.keyframe_insert(data_path=prop,frame=frame,group=name)
        if frame%60==0:print('PERFORMANCE FRAME',frame,flush=True)
    actor.animation_data.action.name='Teaching_Apple_10s'
    for layer in actor.animation_data.action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for curve in bag.fcurves:
                    for key in curve.keyframe_points:key.interpolation='LINEAR'
    for o,visibility in hidden.items():o.hide_viewport=visibility
    reset();bpy.context.scene.frame_set(0);update()
