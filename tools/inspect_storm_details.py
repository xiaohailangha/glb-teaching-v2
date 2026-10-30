import bpy,json,pathlib
root=pathlib.Path(__file__).resolve().parent.parent
rig=bpy.data.objects['RIG-storm']
data={'bones':[],'actions':{},'images':[],'materials':{}}
for b in rig.pose.bones:
    if b.bone.use_deform or b.name.startswith(('CTL','MSTR','FK-','TGT','Properties','PRP-')):
        data['bones'].append({'name':b.name,'deform':b.bone.use_deform,'head':list(b.head),'tail':list(b.tail),'rotation_mode':b.rotation_mode,'props':{k:str(b[k]) for k in b.keys() if k!='cloudrig_component'}})
for a in bpy.data.actions:
    if a.name.startswith('Face'):
        data['actions'][a.name]=[{'path':f.data_path,'index':f.array_index,'value':f.evaluate(1)} for l in a.layers for s in l.strips for bag in s.channelbags for f in bag.fcurves]
for im in bpy.data.images:data['images'].append({'name':im.name,'path':im.filepath,'size':list(im.size),'packed':bool(im.packed_file),'source':im.source})
for m in bpy.data.materials:
    if m.name.startswith('storm'):
        data['materials'][m.name]=[{'name':n.name,'type':n.type,'group':n.node_tree.name if n.type=='GROUP' else None,'inputs':{i.name:list(i.default_value) if hasattr(i.default_value,'__len__') and not isinstance(i.default_value,str) else i.default_value for i in n.inputs if hasattr(i,'default_value') and not i.is_linked and isinstance(i.default_value,(float,int,str)) or hasattr(i,'default_value') and type(i.default_value).__name__=='bpy_prop_array'}} for n in m.node_tree.nodes if n.type in ['BSDF_PRINCIPLED','GROUP','RGB']]
(root/'work/storm/details.json').write_text(json.dumps(data,indent=2,default=str))
print('STORM DETAILS WRITTEN',flush=True)

