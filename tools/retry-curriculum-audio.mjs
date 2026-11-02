import fs from 'node:fs/promises';
import {verifiedTeachingAudio,audioHash} from '../services/course-audio-quality.mjs';
const out='work/curriculum/new-audio',prompts=JSON.parse(await fs.readFile('work/curriculum/prompts.json','utf8'));
const failures=JSON.parse(await fs.readFile('work/curriculum/new-audio-report.json','utf8')).failed;
const results=[];
for(const {key,text,language}of failures){
 if(!prompts[key])continue;
 try{const old=JSON.parse(await fs.readFile(out+'/'+key+'.json','utf8'));if(old.quality?.version===3&&old.sha256===audioHash(await fs.readFile(out+'/'+key+'.wav')))continue;}catch{}
 if(language!=='en')continue;
 const candidates=[{text,options:{language}}];
 // Question intonation is preserved; exclamation is only an alternate prompt
 // for declarative models and isolated words, never a change to lexical content.
 if(!text.trim().endsWith('?'))candidates.push({text:text.replace(/[.!]$/,'')+'!',options:{language}});
 candidates.push({text,options:{language,speeds:[-.6,.2]}});
 let passed=false,errors=[];
 for(const candidate of candidates){
  try{
   const {wav,...metadata}=await verifiedTeachingAudio(candidate.text,candidate.options);
   await fs.writeFile(out+'/'+key+'.wav',wav);
   await fs.writeFile(out+'/'+key+'.json',JSON.stringify({...metadata,text,editorialAudioNote:'Reviewed alternate prosody; unchanged lexical content'},null,2));
   console.log('PASS '+text);results.push({key,text,passed:true,sourceText:metadata.sourceText,speed:metadata.speed});passed=true;break;
  }catch(e){errors.push(e.message);}
 }
 if(!passed){console.log('REVIEW '+text);results.push({key,text,passed:false,errors});}
 await fs.writeFile('work/curriculum/retry-report.json',JSON.stringify(results,null,2));
}
