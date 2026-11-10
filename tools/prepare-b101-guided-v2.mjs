import fs from 'node:fs/promises';
import {verifiedTeachingAudio,audioHash,sameSpeech} from '../services/course-audio-quality.mjs';
import {recognize} from '../services/tencent-speech.mjs';
const dir='work/b101-guided-v2',jobs=JSON.parse(await fs.readFile(dir+'/jobs.json','utf8'));
const report={passed:[],failed:[]};let next=0;
await Promise.all(Array.from({length:2},async()=>{
 while(next<jobs.length){const job=jobs[next++];
  try{
   let meta,wav;
   try{meta=JSON.parse(await fs.readFile(`${dir}/${job.id}.json`,'utf8'));wav=await fs.readFile(`${dir}/${job.id}.wav`);if(meta.text!==job.text||meta.sha256!==audioHash(wav)||!meta.secondPass)meta=null;}catch{}
   if(!meta){
    const result=await verifiedTeachingAudio(job.text,{language:job.language});({wav,...meta}=result);
    const heard=await recognize(wav,{engine:job.language==='zh'?'16k_zh_en_2.0':'16k_en_large'});
    if(!sameSpeech(job.text,heard.text,job.language))throw Error('Second-pass transcript mismatch: '+heard.text);
    meta.secondPass={sha256:audioHash(wav),text:heard.text,at:new Date().toISOString()};
    await fs.writeFile(`${dir}/${job.id}.wav`,wav);await fs.writeFile(`${dir}/${job.id}.json`,JSON.stringify(meta,null,2));
   }
   report.passed.push({id:job.id,text:job.text});console.log('PASS '+job.text);
  }catch(e){report.failed.push({id:job.id,text:job.text,error:e.message});console.log('REVIEW '+job.text+' '+e.message);}
 }
}));
await fs.writeFile(dir+'/report.json',JSON.stringify(report,null,2));
if(report.failed.length)process.exitCode=1;
else{
 const assets=[];for(const job of jobs){const meta=JSON.parse(await fs.readFile(`${dir}/${job.id}.json`,'utf8')),wav=await fs.readFile(`${dir}/${job.id}.wav`);assets.push({id:job.id,text:job.text,language:job.language,size:wav.length,sha256:meta.sha256,duration:meta.duration,cues:meta.cues,wordTimings:meta.wordTimings,quality:meta.quality,secondPass:meta.secondPass});}
 await fs.writeFile(dir+'/manifest.json',JSON.stringify({schema:1,id:audioHash(Buffer.from(JSON.stringify(assets))),assets},null,2));
 await fs.copyFile(dir+'/manifest.json','data/curriculum/teaching-audio.json');
 console.log(`Validated ${assets.length} teaching recordings; local only, not published.`);
}
