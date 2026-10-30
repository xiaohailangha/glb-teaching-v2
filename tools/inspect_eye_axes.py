import bpy,pathlib,json,numpy as np
r=bpy.data.objects['RIG-Snow'];r.animation_data.action=None
for t in r.animation_data.nla_tracks:t.mute=True
o=bpy.data.objects['GEO-snow-eye_anim']
def coords():
 r.update_tag();bpy.context.view_layer.update();ev=o.evaluated_get(bpy.context.evaluated_depsgraph_get());m=ev.to_mesh();a=np.array([v.co[:] for v in m.vertices]);ev.to_mesh_clear();return a
base=coords();out=[]
for name in ['Eye.L','Eye.R','TGT-Eye.L','TGT-Eyes','CEN-Eyes']:
 for prop,amount in [('location',.03),('rotation_euler',.3)]:
  for axis in range(3):
   p=r.pose.bones[name];saved=getattr(p,prop).copy();getattr(p,prop)[axis]+=amount;a=coords()
   out.append({'name':name,'property':prop,'axis':axis,'max':float(np.max(np.abs(a-base))),'eyeRotation':list(r.pose.bones['DEF-Eye.L'].matrix.to_quaternion())})
   setattr(p,prop,saved)
print(json.dumps(out))
(pathlib.Path(__file__).resolve().parents[1]/'work/eye-axes.json').write_text(json.dumps(out,indent=2))
