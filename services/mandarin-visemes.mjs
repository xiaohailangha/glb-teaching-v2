// Reuse the character's approved mouth poses. Timings come from the recorded
// Mandarin SOE phone alignment; tone numbers do not change visible articulation.
const initials={b:21,p:21,m:21,f:18,d:19,t:19,n:19,l:14,g:20,k:20,h:12,j:16,q:16,x:16,zh:16,ch:16,sh:16,r:13,z:15,c:15,s:15,y:6,w:7};
const finals={a:[2],o:[3],e:[4],i:[6],u:[7],v:[7],ai:[2,6],ei:[4,6],ao:[2,7],ou:[8,7],an:[1,19],ang:[2,20],en:[1,19],eng:[1,20],er:[13],ia:[6,2],ie:[6,4],iao:[6,2,7],iu:[6,7],iou:[6,8,7],ian:[6,1,19],in:[6,19],iang:[6,2,20],ing:[6,20],iong:[7,20],ua:[7,2],uo:[7,3],uai:[7,2,6],ui:[7,6],uei:[7,4,6],uan:[7,1,19],un:[7,19],uen:[7,1,19],uang:[7,2,20],ong:[7,20],ve:[7,4],van:[7,1,19],vn:[7,19]};
export function mandarinVisemes(alignment,duration){
 if(!Number.isFinite(duration)||duration<=0)throw Error('Invalid recording duration');
 const cues=[{time:0,id:0}];let previousEnd=0,count=0;
 function add(time,id){time=Math.min(duration,Math.max(0,time));const last=cues.at(-1);if(time<last.time-1e-6)throw Error('Non-monotonic Mandarin phone alignment');if(time===last.time)last.id=id;else if(last.id!==id)cues.push({time,id});}
 for(const word of alignment.Words||[]){let initial='';for(const phone of word.PhoneInfos||[]){
  const name=String(phone.Phone).toLowerCase().replace(/[0-5]/g,''),start=phone.MemBeginTime/1000,end=phone.MemEndTime/1000;
  if(!Number.isFinite(start)||!Number.isFinite(end)||end<start||end>duration+.12||phone.MatchTag!==0)throw Error('Invalid Mandarin phone timing');
  if(end<=start)continue;
  const poses=Object.hasOwn(initials,name)?[initials[name]]:name==='i'&&['zh','ch','sh','r','z','c','s'].includes(initial)?[15]:finals[name];
  if(!poses)throw Error('Unsupported Mandarin phone '+name);
  if(start>previousEnd+.025)add(previousEnd,0);
  for(let i=0;i<poses.length;i++)add(start+(end-start)*i/poses.length,poses[i]);
  previousEnd=end;initial=name;count++;
 }}
 if(!count)throw Error('Mandarin recording has no phone alignment');
 add(previousEnd,0);if(cues.at(-1).time<duration)cues.push({time:duration,id:0});
 return cues;
}
