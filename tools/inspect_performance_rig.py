import bpy,json,pathlib
rig=bpy.data.objects['RIG-Snow']
data={
 'deform':[{'name':b.name,'parent':b.parent.name if b.parent else None,'segments':b.bbone_segments} for b in rig.data.bones if b.use_deform],
 'gaze':[{'name':b.name,'loc':list(b.location),'mode':b.rotation_mode,'constraints':[(c.name,c.type) for c in b.constraints]} for b in rig.pose.bones if any(s in b.name for s in ['Eye_Target','EyeTarget','Eyes','Eye.L','Eye.R','Eye_']) and not b.name.startswith('DEF')],
 'groups':{o.name:[g.name for g in o.vertex_groups] for o in bpy.data.objects if o.type=='MESH' and o.name in ['GEO-snow-body','GEO-snow-head','GEO-snow-eye_anim']}
}
path=pathlib.Path(__file__).resolve().parents[1]/'work/performance-rig.json'
path.write_text(json.dumps(data,indent=2))
print('RIG',len(data['deform']),data['gaze'])
