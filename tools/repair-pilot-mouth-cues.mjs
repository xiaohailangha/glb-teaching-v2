import fs from 'node:fs/promises';import crypto from 'node:crypto';
import {assess,cacheDir,readWave,pcmWave} from '../services/tencent-speech.mjs';
import {mandarinVisemes} from '../services/mandarin-visemes.mjs';
const root='data/teaching-pilot',c=JSON.parse(await fs.readFile(root+'/current.json'));
let aligned=0,requests=0,cursor=0;
const assets=Object.values(c.assets).filter(a=>a.language==='zh');
async function worker(){while(cursor<assets.length){const a=assets[cursor++],hash=crypto.createHash('sha256').update(JSON.stringify({version:1,text:a.text,voice:403008,speed:0,language:'zh'})).digest('hex');
 const original=JSON.parse(await fs.readFile(cacheDir+'/'+hash+'.alignment.json')),wav=await fs.readFile(root+'/'+a.file),{pcm,duration}=readWave(wav);
 let detail=original;const detailFile=root+'/evidence/'+a.sha256+'.mouth-alignment.json';
 try{mandarinVisemes(detail,duration);}catch{
  try{detail=JSON.parse(await fs.readFile(detailFile));mandarinVisemes(detail,duration);}catch{
   const chunks=[];let group=[];
   for(const w of original.Words){if(group.length>=24){chunks.push(group);group=[];}group.push(w);}if(group.length)chunks.push(group);
   const words=[],receipts=[];
   for(const group of chunks){const start=Math.max(0,group[0].MemBeginTime-80),end=Math.min(duration*1000,group.at(-1).MemEndTime+80),text=group.map(w=>w.Word).join('');
    const bytes=pcmWave(pcm.subarray(Math.floor(start*16)*2,Math.ceil(end*16)*2));
    const result=await assess(bytes,{text,language:'zh',strictness:2});requests++;
    if(result.PronCompletion<.98||!result.Words.every(w=>w.MatchTag===0&&w.PhoneInfos?.length))throw Error('Incomplete phone alignment '+a.id);
    receipts.push({startMs:start,endMs:end,text,result});
    const low=group[0].MemBeginTime,high=group.at(-1).MemEndTime,clamp=t=>Math.max(low,Math.min(high,t+start));
    for(const w of result.Words)words.push({...w,MemBeginTime:clamp(w.MemBeginTime),MemEndTime:clamp(w.MemEndTime),PhoneInfos:w.PhoneInfos.map(p=>({...p,MemBeginTime:clamp(p.MemBeginTime),MemEndTime:clamp(p.MemEndTime)})).filter(p=>p.MemEndTime>p.MemBeginTime)});
   }
   detail={Words:words,source:'same-wav-sentence-crops',sha256:a.sha256,receipts};await fs.writeFile(detailFile,JSON.stringify(detail));try{mandarinVisemes(detail,duration);}catch(e){throw Error(a.id+': '+e.message);}
  }
 }
 a.cues=mandarinVisemes(detail,duration);a.cueSource='soe-mandarin-phone-timing';
 const meta=root+'/evidence/'+a.id+'.json';const old=JSON.parse(await fs.readFile(meta));old.cues=a.cues;old.cueSource=a.cueSource;await fs.writeFile(meta,JSON.stringify(old,null,2));aligned++;
 console.log(JSON.stringify({aligned,total:assets.length,newAlignmentRequests:requests}));
}}
await Promise.all([worker(),worker()]);
await fs.writeFile(root+'/current.json',JSON.stringify(c,null,2));
await fs.writeFile(root+'/mouth-cue-check.json',JSON.stringify({revision:c.revision,aligned,total:assets.length,newAlignmentRequests:requests,englishUnchanged:true,wavUnchanged:true,asrCalls:0,ttsCalls:0},null,2));
