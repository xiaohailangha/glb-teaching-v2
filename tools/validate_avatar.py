"""Validate packed GLB structure, geometry preservation and articulation deltas."""
import array,json,math,pathlib,struct

root=pathlib.Path(__file__).resolve().parent.parent

def read(path):
    raw=path.read_bytes();magic,version,size=struct.unpack_from('<III',raw)
    assert magic==0x46546c67 and version==2 and size==len(raw)
    length=struct.unpack_from('<I',raw,12)[0]
    doc=json.loads(raw[20:20+length]);start=20+length
    bin_size,bin_type=struct.unpack_from('<II',raw,start)
    assert bin_type==0x004e4942
    binary=raw[start+8:start+8+bin_size]
    for view in doc['bufferViews']:
        assert view.get('byteOffset',0)%4==0
        assert view.get('byteOffset',0)+view['byteLength']<=len(binary)
    return doc,binary

def floats(doc,binary,index):
    a=doc['accessors'][index]
    assert a['componentType']==5126
    width={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[a['type']]
    values=[0.]*(a['count']*width)
    if 'bufferView' in a:
        view=doc['bufferViews'][a['bufferView']]
        offset=view.get('byteOffset',0)+a.get('byteOffset',0)
        stride=view.get('byteStride',4*width)
        for i in range(a['count']):values[i*width:(i+1)*width]=struct.unpack_from('<'+'f'*width,binary,offset+i*stride)
    if 'sparse' in a:
        sparse=a['sparse'];iv=doc['bufferViews'][sparse['indices']['bufferView']];vv=doc['bufferViews'][sparse['values']['bufferView']]
        kind={5121:'B',5123:'H',5125:'I'}[sparse['indices']['componentType']]
        base=iv.get('byteOffset',0)+sparse['indices'].get('byteOffset',0)
        indices=struct.unpack_from('<'+kind*sparse['count'],binary,base)
        base=vv.get('byteOffset',0)+sparse['values'].get('byteOffset',0)
        updates=struct.unpack_from('<'+'f'*(width*sparse['count']),binary,base)
        for i,index in enumerate(indices):values[index*width:(index+1)*width]=updates[i*width:(i+1)*width]
    assert all(math.isfinite(v) for v in values)
    return values

doc,binary=read(root/'assets/avatar/models/snow.glb')
baseline,old_binary=read(root/'work/baseline/snow.glb')
old_nodes={n['name']:n for n in baseline['nodes'] if 'mesh' in n}
report={'base_geometry_identical':True,'mesh_count':0,'facial_normal_targets':0}
for node in doc['nodes']:
    if 'mesh' not in node:continue
    report['mesh_count']+=1
    mesh=doc['meshes'][node['mesh']];old=baseline['meshes'][old_nodes[node['name']]['mesh']]
    assert len(mesh['primitives'])==len(old['primitives'])
    for primitive,old_primitive in zip(mesh['primitives'],old['primitives']):
        positions=floats(doc,binary,primitive['attributes']['POSITION'])
        assert positions==floats(baseline,old_binary,old_primitive['attributes']['POSITION']),node['name']
        for target in primitive.get('targets',[]):
            deltas=floats(doc,binary,target['POSITION']);assert len(deltas)==len(positions)
            if 'NORMAL' in target:
                report['facial_normal_targets']+=1
                assert node['name'] in ['Snow_head','Snow_eyebrows']
                assert len(floats(doc,binary,target['NORMAL']))==len(positions)
    if node['name']=='Snow_tongue':
        names=mesh['extras']['targetNames'];primitive=mesh['primitives'][0]
        th=floats(doc,binary,primitive['targets'][names.index('TH')]['POSITION'])
        lateral=floats(doc,binary,primitive['targets'][names.index('L')]['POSITION'])
        report['tongue_th_delta_m']=max(abs(x) for x in th)
        report['tongue_l_delta_m']=max(abs(x) for x in lateral)
        report['tongue_th_l_difference_m']=max(abs(x-y) for x,y in zip(th,lateral))
        assert report['tongue_th_l_difference_m']>.002
assert report['mesh_count']==15 and report['facial_normal_targets']>0
(root/'docs/model-validation.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report))
