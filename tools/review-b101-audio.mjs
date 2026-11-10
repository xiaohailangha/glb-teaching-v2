import fs from 'node:fs/promises';
import {recognize,readWave} from '../services/tencent-speech.mjs';
import {audioHash,sameSpeech} from '../services/course-audio-quality.mjs';
const sample=JSON.parse(await fs.readFile('data/curriculum/sample.json','utf8')),dir='work/b101-audio';
const report={passed:[],failed:[]};
for(const a of sample.audio){try{
 const wav=await fs.readFile(`${dir}/${a.id}.wav`),m=JSON.parse(await fs.readFile(`${dir}/${a.id}.json`,'utf8'));
 if(m.sha256!==audioHash(wav)||m.quality.sha256!==m.sha256||!m.quality.alignmentChecked||!m.quality.observations.some(o=>o.accepted))throw Error('First-pass proof mismatch');
 if(m.cues.at(-1).id!==0||Math.abs(m.cues.at(-1).time-m.duration)>.001||m.cues.some((c,i)=>c.time<0||c.time>m.duration||i>0&&c.time<m.cues[i-1].time))throw Error('Cue boundary mismatch');
 const {pcm}=readWave(wav);for(let i=pcm.length-1600;i<pcm.length;i+=2)if(pcm.readInt16LE(i)!==0)throw Error('Missing quiet tail');
 if(m.secondPass?.sha256!==m.sha256){
  const observations=[];
  for(const engine of ['16k_zh_en_2.0','16k_en']){
   const r=await recognize(wav,{engine});const expected=a.text.replace(/\bLin\b/g,'Lynn'),heard=r.text.replace(/\bLin\b/ig,'Lynn');
   observations.push({engine,text:r.text,accepted:sameSpeech(expected,heard)});if(observations.at(-1).accepted)break;
  }
  if(!observations.some(o=>o.accepted))throw Error('Second-pass ASR '+JSON.stringify(observations));
  m.secondPass={sha256:m.sha256,observations,checkedAt:new Date().toISOString(),cueAndQuietTailChecked:true};await fs.writeFile(`${dir}/${a.id}.json`,JSON.stringify(m,null,2));
 }
 report.passed.push(a.id);console.log('VERIFIED '+a.id);
}catch(e){report.failed.push({id:a.id,error:e.message});console.log('REVIEW '+a.id+' '+e.message);}
await fs.writeFile(`${dir}/second-pass.json`,JSON.stringify(report,null,2));}
console.log(JSON.stringify({passed:report.passed.length,failed:report.failed.length}));
