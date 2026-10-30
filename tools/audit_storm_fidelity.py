import bpy,json,pathlib
from mathutils import Vector
root=pathlib.Path(__file__).resolve().parents[1];out=root/'work/storm-fidelity';out.mkdir(exist_ok=True,parents=True)
r=bpy.data.objects['RIG-storm']
r.pose.bones['Properties_Character_Storm']['Anim Eyes']=False
r.pose.bones['Properties']['ik_left_arm']=0.;r.pose.bones['Properties']['ik_right_arm']=0.
r.pose.bones['FK-UpperArm.L'].rotation_euler.z=-1.32;r.pose.bones['FK-UpperArm.R'].rotation_euler.z=1.32
r.update_tag();bpy.context.view_layer.update()
def socket(s):
 try:return list(s.default_value)
 except:
  try:return s.default_value
  except:return None
data={'objects':{},'materials':{},'groups':{}}
for o in bpy.context.scene.objects:
 if o.name.startswith('GEO-storm'):
  data['objects'][o.name]={'type':o.type,'hide_render':o.hide_render,'modifiers':[{'name':m.name,'type':m.type,'levels':getattr(m,'levels',None),'render_levels':getattr(m,'render_levels',None)} for m in o.modifiers]}
def nodes(tree):return {'nodes':[{'name':n.name,'type':n.type,'group':n.node_tree.name if n.type=='GROUP' else None,'image':n.image.name if n.type=='TEX_IMAGE' and n.image else None,'uv_map':getattr(n,'uv_map',None),'attribute_name':getattr(n,'attribute_name',None),'inputs':{s.name:socket(s) for s in n.inputs if not s.is_linked}} for n in tree.nodes],'links':[[l.from_node.name,l.from_socket.name,l.to_node.name,l.to_socket.name] for l in tree.links]}
def groups(tree):
 for n in tree.nodes:
  if n.type=='GROUP' and n.node_tree.name not in data['groups']:data['groups'][n.node_tree.name]=nodes(n.node_tree);groups(n.node_tree)
for name in ['storm-hair-mesh','storm-skin','storm-eyes-iris','storm-eyes-white','storm-eyes-pupil']:
 m=bpy.data.materials.get(name)
 if m and m.use_nodes:data['materials'][name]=nodes(m.node_tree);groups(m.node_tree)
(out/'audit.json').write_text(json.dumps(data,indent=2,default=str))
scene=bpy.context.scene
for o in list(scene.objects):
 if o.type in ['LIGHT','CAMERA']:bpy.data.objects.remove(o,do_unlink=True)
def aim(o,p):o.rotation_euler=(Vector(p)-o.location).to_track_quat('-Z','Y').to_euler()
cam=bpy.data.objects.new('Fidelity_Camera',bpy.data.cameras.new('Fidelity_Camera'));scene.collection.objects.link(cam);cam.location=(.10,-1.9,1.12);aim(cam,(0,0,1.03));cam.data.lens=65;scene.camera=cam
for name,loc,power,size in [('Key',(-2,-3,3),450,3),('Fill',(2,-2,1.8),70,3),('Rim',(1,1,2.5),200,2)]:
 o=bpy.data.objects.new(name,bpy.data.lights.new(name,'AREA'));scene.collection.objects.link(o);o.location=loc;o.data.energy=power;o.data.shape='DISK';o.data.size=size;aim(o,(0,0,1))
scene.world=bpy.data.worlds.new('Fidelity_World');scene.world.use_nodes=True
world_nodes=scene.world.node_tree.nodes;background=world_nodes.new('ShaderNodeBackground');world_out=world_nodes.new('ShaderNodeOutputWorld');scene.world.node_tree.links.new(background.outputs[0],world_out.inputs['Surface']);background.inputs['Color'].default_value=(.12,.12,.12,1);background.inputs['Strength'].default_value=.3
scene.render.engine='CYCLES';scene.cycles.samples=32;scene.cycles.use_denoising=True
scene.render.resolution_x=800;scene.render.resolution_y=800;scene.render.resolution_percentage=100;scene.render.image_settings.file_format='PNG';scene.render.filepath=str(out/'original-blender.png')
print('AUDIT WRITTEN; RENDERING ORIGINAL',flush=True)
bpy.ops.render.render(write_still=True)
