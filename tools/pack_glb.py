"""Keep facial morph normals; compact unreachable GLB accessors and buffers.

The full original model and source rig remain in source-models/ and work/baseline/.
No geometry, materials, textures, target names or face positions are simplified.
"""
import json, pathlib, struct

def pack(path,character='Snow'):
    data=path.read_bytes()
    magic,version,length=struct.unpack_from('<III',data)
    assert magic==0x46546c67 and version==2 and length==len(data)
    offset=12;doc=None;binary=None
    while offset<len(data):
        size,kind=struct.unpack_from('<II',data,offset);offset+=8
        chunk=data[offset:offset+size];offset+=size
        if kind==0x4e4f534a:doc=json.loads(chunk)
        if kind==0x004e4942:binary=chunk
    assert doc and binary and len(doc['buffers'])==1
    removed=0
    face_names=[character+'_'+part for part in ['head','eyebrows','eyes','corneas','eye.L','eye.R','eye_cornea.L','eye_cornea.R']]
    face_meshes={node['mesh'] for node in doc['nodes'] if node.get('name') in face_names and 'mesh' in node}
    assert len(face_meshes)>=2
    for mesh_index,mesh in enumerate(doc['meshes']):
        if mesh_index not in face_meshes:
            for primitive in mesh['primitives']:
                for target in primitive.get('targets',[]):
                    if 'NORMAL' in target:target.pop('NORMAL');removed+=1
    refs=[]
    for skin in doc.get('skins',[]):
        if 'inverseBindMatrices' in skin:refs.append((skin,'inverseBindMatrices'))
    for animation in doc.get('animations',[]):
        for sampler in animation['samplers']:
            refs.extend([(sampler,'input'),(sampler,'output')])
    for mesh in doc['meshes']:
        for primitive in mesh['primitives']:
            refs.extend((primitive['attributes'],key) for key in primitive['attributes'])
            if 'indices' in primitive:refs.append((primitive,'indices'))
            for target in primitive.get('targets',[]):refs.extend((target,key) for key in target)
    accessor_ids=sorted({obj[key] for obj,key in refs})
    accessor_map={old:new for new,old in enumerate(accessor_ids)}
    accessors=[doc['accessors'][i] for i in accessor_ids]
    views=set()
    for accessor in accessors:
        if 'bufferView' in accessor:views.add(accessor['bufferView'])
        if 'sparse' in accessor:
            views.add(accessor['sparse']['indices']['bufferView']);views.add(accessor['sparse']['values']['bufferView'])
    for image in doc.get('images',[]):
        if 'bufferView' in image:views.add(image['bufferView'])
    view_map={old:new for new,old in enumerate(sorted(views))}
    packed=bytearray();new_views=[]
    for index in sorted(views):
        view=dict(doc['bufferViews'][index]);assert view['buffer']==0
        start=view.get('byteOffset',0)
        packed.extend(b'\0'*((-len(packed))%4))
        view['byteOffset']=len(packed);packed.extend(binary[start:start+view['byteLength']]);new_views.append(view)
    for obj,key in refs:obj[key]=accessor_map[obj[key]]
    for accessor in accessors:
        if 'bufferView' in accessor:accessor['bufferView']=view_map[accessor['bufferView']]
        if 'sparse' in accessor:
            for key in ['indices','values']:
                accessor['sparse'][key]['bufferView']=view_map[accessor['sparse'][key]['bufferView']]
    for image in doc.get('images',[]):
        if 'bufferView' in image:image['bufferView']=view_map[image['bufferView']]
    doc['accessors']=accessors;doc['bufferViews']=new_views;doc['buffers'][0]['byteLength']=len(packed)
    packed.extend(b'\0'*((-len(packed))%4))
    encoded=json.dumps(doc,separators=(',',':'),ensure_ascii=False).encode()
    encoded+=b' '*((-len(encoded))%4)
    result=struct.pack('<III',magic,2,28+len(encoded)+len(packed))+struct.pack('<II',len(encoded),0x4e4f534a)+encoded+struct.pack('<II',len(packed),0x004e4942)+packed
    path.write_bytes(result)
    face_normals=sum('NORMAL' in target for i in face_meshes for p in doc['meshes'][i]['primitives'] for target in p.get('targets',[]))
    assert face_normals>0,'Facial morph normals must be exported before packing'
    return {'before_bytes':len(data),'after_bytes':len(result),'removed_rigid_normal_targets':removed,'facial_normal_targets':face_normals,'accessors':len(accessors)}

if __name__=='__main__':
    root=pathlib.Path(__file__).resolve().parent.parent
    report=pack(root/'assets/avatar/models/snow.glb')
    (root/'docs/model-packing.json').write_text(json.dumps(report,indent=2))
    details=json.loads((root/'docs/model-report.json').read_text())
    details['file_bytes']=report['after_bytes']
    (root/'docs/model-report.json').write_text(json.dumps(details,indent=2))
    print(json.dumps(report))
