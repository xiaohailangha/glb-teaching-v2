import fs from 'node:fs/promises';
import {verifiedTeachingAudio,audioHash} from '../services/course-audio-quality.mjs';
const root='scene-preview/assets/avatar/audio',out='work/curriculum/audio-candidates';
await fs.mkdir(out,{recursive:true});
const jobs=[];
for(const file of (await fs.readdir(root)).filter(n=>n.endsWith('.json'))){
 const manifest=JSON.parse(await fs.readFile(root+'/'+file,'utf8'));
 for(const [key,item] of Object.entries(manifest))if(item?.text&&/[a-z]/i.test(item.text)&&!/[\u3400-\u9fff]/.test(item.text)&&!['phoneme','group'].includes(item.kind))jobs.push({file,key,item});
}
const report={started:new Date().toISOString(),total:jobs.length,passed:[],failed:[],contextReview:[]};
let cursor=0;
await Promise.all(Array.from({length:2},async()=>{
 while(cursor<jobs.length){const {file,key,item}=jobs[cursor++];
  if(item.contextWord){report.contextReview.push({file,key,text:item.text});continue;}
  try{const result=await verifiedTeachingAudio(item.text);await fs.writeFile(out+'/'+key+'.wav',result.wav);const {wav,...metadata}=result;await fs.writeFile(out+'/'+key+'.json',JSON.stringify({...item,...metadata},null,2));report.passed.push({file,key,text:item.text,changed:audioHash(await fs.readFile(root+'/'+key+'.wav'))!==metadata.sha256,oldDuration:item.duration,newDuration:metadata.duration});console.log('PASS '+key);}
  catch(e){report.failed.push({file,key,text:item.text,error:e.message});console.log('REVIEW '+key+': '+e.message);}
  await fs.writeFile('work/curriculum/audio-audit.json',JSON.stringify(report,null,2));
 }
}));
report.completed=new Date().toISOString();await fs.writeFile('work/curriculum/audio-audit.json',JSON.stringify(report,null,2));console.log(JSON.stringify({total:jobs.length,passed:report.passed.length,failed:report.failed.length,contextReview:report.contextReview.length}));
