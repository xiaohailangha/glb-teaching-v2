import bpy,json,pathlib
r=bpy.data.objects['RIG-Snow'];out={'actions':{},'drivers':[]}
for name in ['Mouth Teethsmile','Mouth Default','Eyemask Cocky','Eyemask Scared','Eyemask Relaxed']:
 a=bpy.data.actions[name];values=[]
 for layer in a.layers:
  for strip in layer.strips:
   for bag in strip.channelbags:
    for f in bag.fcurves:
     v=f.evaluate(a.frame_range[0])
     if abs(v)>1e-6 and not f.data_path.endswith('scale'):values.append([f.data_path,f.array_index,round(v,5)])
 out['actions'][name]=values
for p in r.pose.bones:
 for c in p.constraints:
  if c.type=='ACTION' and c.action and any(n in c.action.name for n in ['CheekRaise','EyebrowsUp','Eyelid_Lower_CloseOpen','Lips_Up+Wide']):
   out['drivers'].append({'bone':p.name,'action':c.action.name,'control':c.subtarget,'axis':c.transform_channel,'minimum':c.min,'maximum':c.max,'start':c.frame_start,'end':c.frame_end})
path=pathlib.Path(__file__).resolve().parents[1]/'work/expression-controls.json';path.write_text(json.dumps(out,indent=2));print(json.dumps(out))
