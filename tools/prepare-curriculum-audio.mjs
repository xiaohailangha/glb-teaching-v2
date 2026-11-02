import fs from 'node:fs/promises';
import {verifiedTeachingAudio,audioHash,audioQualityVersion} from '../services/course-audio-quality.mjs';
const out='work/curriculum/new-audio';
await fs.mkdir(out,{recursive:true});
const jobs=Object.entries(JSON.parse(await fs.readFile('work/curriculum/prompts.json','utf8')));
const report={started:new Date().toISOString(),total:jobs.length,passed:[],failed:[]};
let cursor=0;
let saving=Promise.resolve();
function save(){const data=JSON.stringify(report,null,2);return saving=saving.then(()=>fs.writeFile('work/curriculum/new-audio-report.json',data));}
await Promise.all(Array.from({length:3},async()=>{
 while(cursor<jobs.length){const [key,item]=jobs[cursor++];
  try{
   let previous;
   try{previous=JSON.parse(await fs.readFile(out+'/'+key+'.json','utf8'));}catch{}
   const senseValid=!/\b(read|close|excuse)\b/i.test(item.text)||previous?.sourcePhones?.every(w=>w.word.toLowerCase()==='read'?w.phones.includes('iy'):['close','excuse'].includes(w.word.toLowerCase())?w.phones.at(-1)==='z':true);
   if(senseValid&&previous?.quality?.version===audioQualityVersion&&previous.sha256===audioHash(await fs.readFile(out+'/'+key+'.wav'))){report.passed.push({key,text:item.text,cached:true});continue;}
   const {wav,...metadata}=await verifiedTeachingAudio(item.text,{language:item.language});
   await fs.writeFile(out+'/'+key+'.wav',wav);
   await fs.writeFile(out+'/'+key+'.json',JSON.stringify(metadata,null,2));
   report.passed.push({key,text:item.text});console.log('PASS '+key+' '+item.text);
  }catch(e){report.failed.push({key,...item,error:e.message});console.log('REVIEW '+item.text+' '+e.message);}
  await save();
 }
}));
report.completed=new Date().toISOString();await save();
console.log(JSON.stringify({total:jobs.length,passed:report.passed.length,failed:report.failed.length}));
