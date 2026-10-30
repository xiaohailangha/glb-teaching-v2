"""Bake the original procedural PBR channels, including strand normals.

Read shader inputs directly through emission so subsurface scattering does not
contaminate the albedo bake. Preserve original named UV maps until all bakes end.
"""
import bpy

def shader_channel(materials, channel):
    changes=[];seen=set()
    def visit(tree):
        if tree in seen:return
        seen.add(tree)
        for node in list(tree.nodes):
            if node.type=='GROUP':visit(node.node_tree)
            if node.type!='BSDF_PRINCIPLED':continue
            source=node.inputs[channel];emission=tree.nodes.new('ShaderNodeEmission')
            if source.is_linked:tree.links.new(source.links[0].from_socket,emission.inputs['Color'])
            else:
                value=source.default_value
                emission.inputs['Color'].default_value=tuple(value) if hasattr(value,'__len__') else (value,value,value,1)
            destinations=[link.to_socket for link in list(node.outputs['BSDF'].links)]
            for dst in destinations:tree.links.new(emission.outputs[0],dst)
            changes.append((tree,node,emission,destinations))
    for mat in materials:visit(mat.node_tree)
    return changes

def restore(changes):
    for tree,node,emission,destinations in changes:
        for dst in destinations:tree.links.new(node.outputs['BSDF'],dst)
        tree.nodes.remove(emission)

def bake_material(obj,part,out):
    scene=bpy.context.scene;scene.cycles.samples=16
    out.mkdir(exist_ok=True,parents=True)
    for o in bpy.context.selected_objects:o.select_set(False)
    obj.hide_set(False);obj.hide_render=False;obj.select_set(True);bpy.context.view_layer.objects.active=obj
    uv=obj.data.uv_layers.new(name='RuntimeUV');obj.data.uv_layers.active=uv
    bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(island_margin=.012);bpy.ops.object.mode_set(mode='OBJECT')
    if len(obj.data.uv_layers)>1:obj.data.uv_layers[0].active_render=True
    materials=set(s.material for s in obj.material_slots if s.material)
    maps={};size=2048 if part in ['head','hair_base','hair_clumps'] else 1024
    for channel in ['Base Color','Roughness','Normal']:
        path=out/(part+'-'+channel.replace(' ','-')+'.png')
        cached=path.exists()
        image=bpy.data.images.load(str(path),check_existing=False) if cached else bpy.data.images.new('Storm_'+part+'_'+channel,width=size,height=size,alpha=False)
        image.colorspace_settings.name='sRGB' if channel=='Base Color' else 'Non-Color'
        if not cached:
            targets=[]
            for mat in materials:
                n=mat.node_tree.nodes.new('ShaderNodeTexImage');n.image=image;mat.node_tree.nodes.active=n;targets.append((mat,n))
            changes=shader_channel(materials,channel) if channel!='Normal' else []
            try:
                if channel=='Normal':bpy.ops.object.bake(type='NORMAL',normal_space='TANGENT',normal_r='POS_X',normal_g='POS_Y',normal_b='POS_Z',use_clear=True,margin=16,uv_layer='RuntimeUV')
                else:bpy.ops.object.bake(type='EMIT',use_clear=True,margin=16,uv_layer='RuntimeUV')
                image.filepath_raw=str(path);image.file_format='PNG';image.save()
            finally:
                restore(changes)
                for mat,n in targets:mat.node_tree.nodes.remove(n)
        maps[channel]=image
        print('PBR BAKED',part,channel,flush=True)
    mat=bpy.data.materials.new('Runtime_storm_'+part);mat.use_nodes=True
    bs=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    for channel,image in maps.items():
        tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=image;tex.label=channel
        if channel=='Normal':
            normal=mat.node_tree.nodes.new('ShaderNodeNormalMap');normal.uv_map='RuntimeUV'
            mat.node_tree.links.new(tex.outputs['Color'],normal.inputs['Color']);mat.node_tree.links.new(normal.outputs['Normal'],bs.inputs['Normal'])
        else:mat.node_tree.links.new(tex.outputs['Color'],bs.inputs[channel])
    if part.startswith('hair'):
        bs.inputs['Sheen Weight'].default_value=.5;bs.inputs['Sheen Tint'].default_value=(1,.716,.349,1)
        bs.inputs['Anisotropic'].default_value=.5
    obj.data.materials.clear();obj.data.materials.append(mat)
    for p in obj.data.polygons:p.material_index=0
    for layer in list(obj.data.uv_layers):
        if layer.name!='RuntimeUV':obj.data.uv_layers.remove(layer)
    obj.data.uv_layers.active=obj.data.uv_layers['RuntimeUV'];obj.data.uv_layers.active.active_render=True
    obj.hide_render=True;obj.select_set(False)
