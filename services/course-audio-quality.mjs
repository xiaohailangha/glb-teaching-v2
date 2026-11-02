import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
import {teachingAudio,recognize,readWave,pcmWave,cacheDir} from './tencent-speech.mjs';

export const audioQualityVersion=3;
export const audioHash=b=>crypto.createHash('sha256').update(b).digest('hex');
export function normalizedSpeech(text){
 const numbers={0:'zero',1:'one',2:'two',3:'three',4:'four',5:'five',6:'six',7:'seven',8:'eight',9:'nine',10:'ten',11:'eleven',12:'twelve'};
 return text.toLowerCase().replace(/[’‘]/g,"'").replace(/\b\d+\b/g,n=>numbers[n]??n).replace(/[^a-z0-9']/g,' ').trim().replace(/\s+/g,' ');
}
export function sameSpeech(expected,heard,language='en'){
 if(language==='zh'){
  const norm=t=>t.replace(/[^\p{L}\p{N}]/gu,'').replace(/作/g,'做');
  const homophones={'鸡肉':['肌肉'],'茶':['察'],'食糖':['食塘'],'尝试':['常氏'],'书页':['输液'],'开心的':['开心得']};
  return norm(expected)===norm(heard) || Boolean(homophones[norm(expected)]?.includes(norm(heard)));
 }
 const a=normalizedSpeech(expected),b=normalizedSpeech(heard).replace(/\bipay\b/g,'i pay');
 // A recognizer may spell an isolated homophone as a letter or another word.
 // Only exact, explicitly reviewed pronunciations qualify; no edit-distance gate.
 const isolated={tea:['t'],two:['to','too'],too:['two','to'],four:['for'],one:['won'],eight:['ate'],eye:['i'],i:['eye'],right:['write'],write:['right'],no:['know'],know:['no']};
 return a===b || Boolean(isolated[a]?.includes(b));
}
export function validateWordAlignment(text,words){
 const expected=normalizedSpeech(text).split(' ');
 if(!Array.isArray(words)||words.length!==expected.length||words.some((w,i)=>normalizedSpeech(w.Word)!==expected[i]||w.MatchTag!==0||!Number.isFinite(w.PronAccuracy)||w.PronAccuracy<(expected.length>1&&['a','an','the','to','of','and','am','are','you','your','from'].includes(expected[i])?80:90)||!w.PhoneInfos?.length))throw Error('Word/accuracy alignment gate failed: '+text);
 let end=-1;
 for(const w of words){if(w.MemBeginTime<end||w.MemEndTime<=w.MemBeginTime)throw Error('Invalid word timing: '+text);end=w.MemEndTime;}
}
export function canonicalCues(cues,duration){
 if(cues.some((c,i)=>!Number.isFinite(c.time)||c.time<-.000125||c.time>duration+.000125||(i&&c.time<cues[i-1].time-.000125)))throw Error('Invalid source cue timing');
 return cues.map(c=>({...c,time:Math.min(duration,Math.max(0,Math.round(c.time*16000)/16000))})).sort((a,b)=>a.time-b.time).filter((c,i,a)=>i===a.length-1||c.time!==a[i+1].time);
}
export function isolateAlignedSpeech(wav,words,cues,{padding=.05,tailPadding=.07}={}){
 const {pcm}=readWave(wav);
 const start=Math.max(0,words[0].MemBeginTime/1000-padding),end=Math.min(pcm.length/32000,words.at(-1).MemEndTime/1000+tailPadding);
 const cut=Buffer.from(pcm.subarray(Math.floor(start*16000)*2,Math.ceil(end*16000)*2));
 if(!cut.length)throw Error('Empty speech segment');
 for(let i=0;i<32&&i*4<cut.length;i++){cut.writeInt16LE(Math.round(cut.readInt16LE(i*2)*i/32),i*2);const p=cut.length-2-i*2;cut.writeInt16LE(Math.round(cut.readInt16LE(p)*i/32),p);}
 const lead=.08,tail=.12,result=pcmWave(Buffer.concat([Buffer.alloc(lead*32000),cut,Buffer.alloc(tail*32000)])),duration=(result.length-44)/32000;
 return {wav:result,duration,trim:{start,end,lead,tail},cues:canonicalCues([{time:0,id:0},...cues.filter(c=>c.time>=start&&c.time<=end).map(c=>({...c,time:c.time-start+lead})),{time:duration-tail,id:0},{time:duration,id:0}],duration),wordTimings:words.map(w=>({word:w.Word,start:w.MemBeginTime/1000-start+lead,end:w.MemEndTime/1000-start+lead}))};
}
async function candidateAudio(text,{language='en',voice=403008,speed=0}={}){
 // A sentence terminator prevents the TTS model continuing an isolated word.
 const contexts={read:{text:'Read the sentence.',word:'read',phones:['r','iy','d']},close:{text:'Please close the door.',word:'close',phones:['k','l','ow','z']},excuse:{text:'Excuse me.',word:'excuse',phones:['ih','k','s','k','y','uw','z']}};
 const context=language==='en'?contexts[text.trim().toLowerCase()]:null;
 const sourceText=context?.text??(/[.!?。！？]$/.test(text.trim())?text.trim():text.trim()+(language==='en'?'.':'。'));
 const source=await teachingAudio(sourceText,{voice,language,speed});
 const raw=await fs.readFile(path.join(cacheDir,source.key+'.wav'));
 let result={wav:raw,duration:source.duration,cues:source.cues,wordTimings:[]};
 if(language==='en'){
  const alignment=JSON.parse(await fs.readFile(path.join(cacheDir,source.key+'.alignment.json'),'utf8'));
  validateWordAlignment(context?sourceText:text,alignment.Words);
  // All occurrences in this beginner curriculum use the present-tense verbs.
  for(const w of alignment.Words){
   const form=w.Word.toLowerCase(),phones=w.PhoneInfos.map(p=>p.Phone);
   if(form==='read'&&!phones.includes('iy')||['close','excuse'].includes(form)&&phones.at(-1)!=='z')throw Error('Wrong course-sense pronunciation: '+w.Word);
  }
  const words=context?alignment.Words.filter(w=>w.Word.toLowerCase()===context.word):alignment.Words;
  if(context&&(words.length!==1||JSON.stringify(words[0].PhoneInfos.map(p=>p.Phone))!==JSON.stringify(context.phones)))throw Error('Wrong homograph pronunciation: '+text);
  result=isolateAlignedSpeech(raw,words,source.cues,context?{padding:0,tailPadding:0}:{});
  result.sourcePhones=words.map(w=>({word:w.Word,phones:w.PhoneInfos.map(p=>p.Phone),accuracy:w.PronAccuracy}));
  if(context)result.contextWord={text:sourceText,start:words[0].MemBeginTime/1000,end:words[0].MemEndTime/1000,phones:context.phones};
 }
 const sha256=audioHash(result.wav),qualityFile=path.join(cacheDir,sha256+'.quality-v3.json');
 let quality;try{quality=JSON.parse(await fs.readFile(qualityFile,'utf8'));}catch{}
 if(!quality){
  const engines=language==='en'?['16k_en_large','16k_zh_en_2.0']:['16k_zh_en_2.0'];
  const observations=[];
  for(const engine of engines){
   const heard=await recognize(result.wav,{engine});
   observations.push({engine,text:heard.text,accepted:sameSpeech(text,heard.text,language)});
   if(observations.at(-1).accepted)break;
  }
  if(!observations.some(o=>o.accepted))throw Error('Independent ASR mismatch: '+JSON.stringify({expected:text,observations}));
  quality={version:audioQualityVersion,sha256,observations,checkedAt:new Date().toISOString(),alignmentChecked:language==='en',method:'word alignment plus independent unrestricted ASR; explicit isolated homophones only'};
  await fs.writeFile(qualityFile,JSON.stringify(quality,null,2));
 }
 return {...result,text,sourceText,voice,speed,bundled:true,sourceKey:source.key,sha256,quality};
}


export async function verifiedTeachingAudio(text,options={}){
 const errors=[];
 for(const speed of options.speeds??[0,-.2,-.4]){
  try{return await candidateAudio(text,{...options,speed});}
  catch(error){errors.push({speed,error:error.message});}
 }
 throw Error('All voice candidates require review: '+JSON.stringify(errors));
}
