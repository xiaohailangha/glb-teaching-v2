import bpy,json,pathlib
r=bpy.data.objects['RIG-Snow'];r.animation_data.action=None
for t in r.animation_data.nla_tracks:t.mute=True
r.pose.bones['Properties']['ik_left_upperarm']=0;r.pose.bones['Properties']['ik_right_upperarm']=0
def result():
 r.update_tag();bpy.context.view_layer.update()
 return {n:[round(v,4) for v in r.pose.bones[n].head] for n in ['FK-UpperArm.L','FK-Forearm.L','FK-Wrist.L']}
data=[]
for upper in [-1.32,-.7,-.3]:
 for axis in range(3):
  for angle in [-1.5,1.5]:
   r.pose.bones['FK-UpperArm.L'].rotation_euler=(0,0,upper)
   r.pose.bones['FK-Forearm.L'].rotation_euler=(0,0,0);r.pose.bones['FK-Forearm.L'].rotation_euler[axis]=angle
   data.append({'upper':upper,'axis':axis,'angle':angle,'positions':result()})
(pathlib.Path(__file__).resolve().parents[1]/'work/gesture-axes.json').write_text(json.dumps(data,indent=2))
print(data)
