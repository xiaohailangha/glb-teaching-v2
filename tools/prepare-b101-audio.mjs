import fs from 'node:fs/promises';
import {verifiedTeachingAudio,audioHash,audioQualityVersion} from '../services/course-audio-quality.mjs';
import {namePhrase} from './b101-name-audio.mjs';
const sample=JSON.parse(await fs.readFile('data/curriculum/sample.json','utf8'));
const dir='work/b101-audio';await fs.mkdir(dir,{recursive:true});
const report={total:sample.audio.length,passed:[],failed:[]};
for(const item of sample.audio){
 try{
  let meta;try{meta=JSON.parse(await fs.readFile(`${dir}/${item.id}.json`,'utf8'));if(meta.text!==item.text||meta.quality.version!==audioQualityVersion||meta.sha256!==audioHash(await fs.readFile(`${dir}/${item.id}.wav`)))meta=null;}catch{}
  if(!meta){
   const alias=['B101-im-lin','B101-my-name-lin','B101-goodbye-lin'].includes(item.id);
   const source=item.text.replace(/[’‘]/g,"'").replace(/\bLin\b/g,alias?'Lynn':'Lin');
   let result;try{result=await verifiedTeachingAudio(source);}catch(e){if(!alias)throw e;result=await namePhrase(item.text);}
   const {wav,...m}=result;
   if(alias&&JSON.stringify(m.sourcePhones.find(w=>w.word.toLowerCase()==='lynn')?.phones)!==JSON.stringify(['l','ih','n']))throw Error('Lin phonetic alias must be l ih n');
   meta={...m,text:item.text,...(alias?{phoneticAlias:{display:'Lin',synthesis:'Lynn',phones:['l','ih','n']}}:{})};
   await fs.writeFile(`${dir}/${item.id}.wav`,wav);await fs.writeFile(`${dir}/${item.id}.json`,JSON.stringify(meta,null,2));
  }
  report.passed.push(item.id);console.log('PASS '+item.id);
 }catch(e){report.failed.push({id:item.id,text:item.text,error:e.message});console.log('REVIEW '+item.id+' '+e.message);}
 await fs.writeFile(`${dir}/report.json`,JSON.stringify(report,null,2));
}
console.log(JSON.stringify({passed:report.passed.length,failed:report.failed.length}));
