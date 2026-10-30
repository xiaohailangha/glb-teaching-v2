import bpy,json,pathlib
rig=bpy.data.objects['RIG-Snow']
def curves(a):
    if hasattr(a,'fcurves'): return list(a.fcurves)
    return [f for l in a.layers for s in l.strips for cb in s.channelbags for f in cb.fcurves]
res={}
for name in ['Mouth Oo','Mouth Ff','Mouth Uu','Mouth Opensmile','Mouth Default','Eyemask Closed','RIG-snow-JawOpen','RIG-snow-Eyelid_Upper_CloseOpen','Bodyposes']:
    a=bpy.data.actions[name]
    fs=curves(a)
    res[name]={'slots':[(s.identifier,s.target_id_type) for s in a.slots], 'curves':[{'path':f.data_path,'index':f.array_index,'keys':[(p.co.x,p.co.y) for p in f.keyframe_points]} for f in fs]}
res['object_materials']={o.name:[s.material.name if s.material else None for s in o.material_slots] for o in bpy.context.scene.objects if o.type=='MESH' and o.name.startswith('GEO-')}
res['rig_initial']={'action':str(rig.animation_data.action) if rig.animation_data else None,'frame':bpy.context.scene.frame_current,'props':{k:str(rig[k]) for k in rig.keys()},'bones':[{'name':b.name,'location':list(b.location),'rotation':list(b.rotation_euler),'scale':list(b.scale),'props':{k:str(b[k]) for k in b.keys()}} for b in rig.pose.bones if b.name in ['MSTR-Jaw','MSTR-Mouth','FK-Head','FK-Neck','MSTR-Eyes'] or 'Jaw' in b.name or b.name=='Properties']}
pathlib.Path('work/control-details.json').write_text(json.dumps(res,indent=2),encoding='utf8')
print('CONTROLS_SAVED')
