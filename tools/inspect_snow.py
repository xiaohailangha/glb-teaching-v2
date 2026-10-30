import bpy, json, pathlib
data = {'objects': [], 'actions': [], 'materials': []}
for o in bpy.data.objects:
    item={'name':o.name,'type':o.type,'hide':o.hide_render,'hide_viewport':o.hide_viewport, 'parent':o.parent.name if o.parent else None}
    if o.type=='MESH':
        item.update(vertices=len(o.data.vertices),polygons=len(o.data.polygons),materials=[m.name if m else None for m in o.data.materials],modifiers=[{'name':m.name,'type':m.type,'show_viewport':m.show_viewport,'show_render':m.show_render} for m in o.modifiers],shape_keys=[k.name for k in o.data.shape_keys.key_blocks] if o.data.shape_keys else [])
    if o.type=='ARMATURE':
        item['bones']=[{'name':p.name,'head':list(p.head),'tail':list(p.tail),'props':{k:str(p[k]) for k in p.keys() if k!='_RNA_UI'}} for p in o.pose.bones if not p.name.startswith(('DEF','ORG','MCH','GIZ','STR','TGT'))]
    data['objects'].append(item)
for a in bpy.data.actions:
    data['actions'].append({'name':a.name,'frames':list(a.frame_range)})
for m in bpy.data.materials:
    data['materials'].append({'name':m.name,'nodes':[{'name':n.name,'type':n.type,'image':n.image.filepath if n.type=='TEX_IMAGE' and n.image else None} for n in m.node_tree.nodes] if m.use_nodes else []})
out=pathlib.Path(__file__).parent/'snow-inspection.json'
out.write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf8')
print('INSPECTION',out)
print('SCENE',[(o.name,o.type) for o in bpy.context.scene.objects])
