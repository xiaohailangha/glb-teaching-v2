import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
import {pilotRevision,pilotLessons,wordGuides,repairMessages} from '../services/teaching-pilot-content.mjs';
import {synthesize,assess,recognize,teachingAudio,cacheDir,readWave} from '../services/tencent-speech.mjs';
import {soundTips} from '../services/teaching-pilot.mjs';
const root=path.resolve('data/teaching-pilot');
await fs.mkdir(root+'/audio',{recursive:true});
await fs.mkdir(root+'/evidence',{recursive:true});
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
const read=async f=>JSON.parse(await fs.readFile(f,'utf8'));
const {release}=await read('data/curriculum/cloud-runtime/current.json');
const dir='data/curriculum/cloud-runtime/releases/'+release;
const index=await read(dir+'/index.json');
const assets={},byText=new Map();
const archive='C:/Users/dyw/Documents/CodexActive/2026-11-03/snow-speaks/production/outputs';
const packages=await fs.readdir(archive,{withFileTypes:true});
// Prefer exact original recordings, including independently authored word clips.
for(const c of index.catalog.courses){const d=await read(dir+'/'+index.lessons[c.id].path);for(const a of d.audio)if(a.language==='en'&&a.text.toLowerCase().replace(/[.!?]+$/,'')!=='a'&&!byText.has(a.text.toLowerCase().replace(/[.!?]+$/,'')))byText.set(a.text.toLowerCase().replace(/[.!?]+$/,''),a);}
const english=new Set(pilotLessons.flatMap(l=>l.steps.flatMap(s=>[...s.models,...s.answers,...(s.practiceAnswers||[])])));
for(const w of Object.keys(wordGuides))if(byText.has(w))english.add(w);
for(const chunk of ['despite the difficulty','although this is difficult','a banana'])english.add(chunk);
const englishIds={};
for(const text of english){const original=byText.get(text.toLowerCase().replace(/[.!?]+$/,''));let a;
 if(original){
  const file='audio/'+original.sha256+'.wav';let wav;
  try{wav=await fs.readFile(root+'/'+file);}catch{}
  if(!wav)for(const pkg of packages.filter(p=>p.isDirectory())){try{const b=await fs.readFile(path.join(archive,pkg.name,'media',original.id+'.wav'));if(hash(b)===original.sha256){wav=b;break;}}catch{}}
  if(!wav)throw Error('Original audio unavailable '+original.text+' '+original.id);
  if(wav.length!==original.size||hash(wav)!==original.sha256)throw Error('Original checksum');
  await fs.writeFile(root+'/'+file,wav);a={...original,source:'pilot',originalSource:{release,id:original.id},file};delete a.url;
 }
 else{const clip=await teachingAudio(/[.!?]$/.test(text)?text:text+'.',{voice:403008,language:'en'});const wav=await fs.readFile(path.join(cacheDir,clip.key+'.wav'));const alignment=await read(path.join(cacheDir,clip.key+'.alignment.json'));if(alignment.PronAccuracy<90||alignment.PronCompletion<.98||alignment.Words.some(w=>w.MatchTag!==0||w.PronAccuracy<80))throw Error('English quality '+text);const digest=hash(wav);await fs.writeFile(root+'/audio/'+digest+'.wav',wav);a={id:'en-'+digest,text,voice:403008,language:'en',sha256:digest,size:wav.length,cues:clip.cues,file:'audio/'+digest+'.wav',source:'pilot'};await fs.writeFile(root+'/evidence/'+digest+'.json',JSON.stringify({text,alignment,cueSource:'soe-phone-timing'},null,2));}
 assets[a.id]=a;englishIds[text]=a.id;
}
// Narration has real waveform-driven mouth opening, never fabricated phone timing.
function narrationCues(wav){const {pcm}=readWave(wav);const cues=[{time:0,id:0}];let previous=-1;for(let offset=0;offset<pcm.length;offset+=1280){let sum=0,n=0;for(let j=offset;j<Math.min(offset+1280,pcm.length);j+=2){const x=pcm.readInt16LE(j)/32768;sum+=x*x;n++;}const rms=Math.sqrt(sum/Math.max(1,n));const id=rms<.012?0:rms<.075?1:2;if(id!==previous){cues.push({time:offset/32000,id});previous=id;}}cues.push({time:pcm.length/32000,id:0});return cues;}
const narrations=[...new Set([...pilotLessons.flatMap(l=>l.steps.map(s=>s.body)),...Object.values(wordGuides),...Object.values(repairMessages),...Object.values(soundTips)])];
const narrationIds={};let cursor=0,finished=0;
async function worker(){while(cursor<narrations.length){const text=narrations[cursor++],id='zh-'+hash(text),meta=root+'/evidence/'+id+'.json';let a;try{a=await read(meta);const wav=await fs.readFile(root+'/'+a.file);if(hash(wav)!==a.sha256||a.text!==text)throw Error();}catch{
 const key=hash(JSON.stringify({version:1,text,voice:403008,speed:0,language:'zh'}));let wav;try{wav=await fs.readFile(path.join(cacheDir,key+'.wav'));}catch{const raw=await synthesize(text,{voice:403008});wav=raw.wav;await fs.writeFile(path.join(cacheDir,key+'.wav'),wav);await fs.writeFile(path.join(cacheDir,key+'.raw.json'),JSON.stringify({...raw,wav:undefined}));}
 let result;try{result=await read(path.join(cacheDir,key+'.alignment.json'));}catch{result=await assess(wav,{text,language:'zh',strictness:2});await fs.writeFile(path.join(cacheDir,key+'.alignment.json'),JSON.stringify(result));}
 const normalized=s=>s.replace(/[^\p{Script=Han}]/gu,'').replace(/作/g,'做');
 if(result.PronAccuracy<90||result.PronCompletion<.98||normalized(result.Words.map(w=>w.Word).join(''))!==normalized(text))throw Error('Narration SOE quality '+text);
 const digest=hash(wav);await fs.writeFile(root+'/audio/'+digest+'.wav',wav);
 a={id,text,voice:403008,language:'zh',sha256:digest,size:wav.length,cues:narrationCues(wav),file:'audio/'+digest+'.wav',source:'pilot',cueSource:'actual-waveform-energy',quality:{accuracy:result.PronAccuracy,completion:result.PronCompletion}};
 await fs.writeFile(meta,JSON.stringify(a,null,2));
 }
 assets[id]=a;narrationIds[text]=id;finished++;console.log('Narration '+finished+'/'+narrations.length);
}}
await Promise.all([worker(),worker()]);
const lessons=pilotLessons.map(l=>({...l,steps:l.steps.map(s=>({...s,narration:narrationIds[s.body],audio:s.models.map(t=>englishIds[t])}))}));
// The capture boundary is the end of real speech plus a short safety margin,
// not the end of a file's trailing silence. Original WAVs/cues are unchanged.
for(const a of Object.values(assets).filter(a=>a.language==='en')){
 const {pcm}=readWave(await fs.readFile(root+'/'+a.file));let last=0;
 for(let i=0;i<pcm.length;i+=320){let sum=0,n=0;for(let j=i;j<Math.min(i+320,pcm.length);j+=2){sum+=(pcm.readInt16LE(j)/32768)**2;n++;}if(Math.sqrt(sum/Math.max(1,n))>.004)last=Math.min(i+320,pcm.length);}
 let phoneEnd=0;for(let i=0;i<a.cues.length-1;i++)if(a.cues[i].id!==0)phoneEnd=Math.max(phoneEnd,a.cues[i+1].time*1000);
 a.speechEndMs=Math.min(pcm.length/32,Math.max(last/32,phoneEnd)+60);
}
const content={schema:'snow-speaks.teaching-pilot/1',revision:pilotRevision,release,lessons,assets,englishIds,narrationIds,guides:wordGuides,messages:repairMessages};
await fs.writeFile(root+'/current.json',JSON.stringify(content,null,2));
console.log(JSON.stringify({revision:pilotRevision,lessons:lessons.map(l=>({id:l.id,steps:l.steps.length,oral:l.steps.filter(s=>s.answers.length).length})),assets:Object.keys(assets).length}));
