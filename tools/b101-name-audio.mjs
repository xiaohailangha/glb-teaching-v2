import fs from 'node:fs/promises';
import path from 'node:path';
import {teachingAudio,recognize,cacheDir} from '../services/tencent-speech.mjs';
import {validateWordAlignment,isolateAlignedSpeech,audioHash,sameSpeech} from '../services/course-audio-quality.mjs';
// Re-synthesize a complete thought, then retain the aligned whole target phrase.
// Never splice a final consonant or relax the word/independent ASR gates.
export async function namePhrase(text){
 const target=text.replace(/[’‘]/g,"'").replace(/\bLin\b/g,'Lynn'),count=target.trim().split(/\s+/).length;
 const errors=[];
 for(const prefix of ['','Hello. ','Well, '])for(const suffix of ['',' Nice to meet you.',' See you soon.'])for(const speed of [0,-.2,-.4]){
  const sourceText=prefix+target+suffix;
  try{
   const s=await teachingAudio(sourceText,{voice:403008,speed,language:'en'});
   const a=JSON.parse(await fs.readFile(path.join(cacheDir,s.key+'.alignment.json'),'utf8'));
   validateWordAlignment(sourceText,a.Words);
   const words=a.Words.slice(prefix?1:0,(prefix?1:0)+count);
   if(JSON.stringify(words.at(-1).PhoneInfos.map(p=>p.Phone))!==JSON.stringify(['l','ih','n']))throw Error('Wrong name phones');
   const r=isolateAlignedSpeech(await fs.readFile(path.join(cacheDir,s.key+'.wav')),words,s.cues);
   const heard=await recognize(r.wav,{engine:'16k_en_large'});
   if(!sameSpeech(target,heard.text.replace(/\bLin\b/ig,'Lynn')))throw Error('ASR mismatch '+heard.text);
   const sha256=audioHash(r.wav);
   return {...r,text,sourceText,voice:403008,speed,sha256,sourceKey:s.key,bundled:true,sourcePhones:words.map(w=>({word:w.Word,phones:w.PhoneInfos.map(p=>p.Phone),accuracy:w.PronAccuracy})),quality:{version:3,sha256,alignmentChecked:true,observations:[{engine:heard.engine,text:heard.text,accepted:true}],method:'strict full context alignment; whole phrase extraction; independent ASR',checkedAt:new Date().toISOString()}};
  }catch(e){errors.push(e.message);}
 }
 throw Error('Name phrase requires review: '+errors.join('; '));
}
