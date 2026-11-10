import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
import {pilotRevision,pilotLessons,wordGuides,repairMessages} from '../services/teaching-pilot-content.mjs';
import {synthesize,assess,recognize,teachingAudio,cacheDir,readWave} from '../services/tencent-speech.mjs';
import {mandarinVisemes} from '../services/mandarin-visemes.mjs';
import {soundTips} from '../services/teaching-pilot.mjs';
const root=path.resolve('data/teaching-pilot'),build=path.join(root,'.build');
for(const name of ['audio','evidence','.build'])await fs.mkdir(path.join(root,name),{recursive:true});
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
const read=async f=>JSON.parse(await fs.readFile(f,'utf8'));
const old=await read(root+'/current.json');
const assets={},englishIds={},narrationIds={};
const normalized=s=>s.toLowerCase().replace(/[.!?]+$/,'').trim();
const chinese=s=>s.replace(/[^\p{Script=Han}]/gu,'').replace(/作/g,'做').replace(/原音|原因/g,'元音').replace(/上颚/g,'上腭').replace(/口型/g,'口形').replace(/在学/g,'再学').replace(/[他她]/g,'它').replace(/一会儿/g,'一会').replace(/震动/g,'振动').replace(/齿尖音/g,'齿间音').replace(/题意/g,'提议').replace(/恋/g,'练');
function split(text){
 const clauses=text.match(/[^。！？；，]+[。！？；，]?/g)||[text],parts=[];let current='';
 for(const clause of clauses){if(current&&chinese(current+clause).length>28){parts.push(current);current='';}if(chinese(clause).length>36)throw Error('Narration needs an authored pause: '+clause);current+=clause;}
 if(current)parts.push(current);return parts;
}
function boundary(wav,cues){const {pcm}=readWave(wav);let last=0;for(let i=0;i<pcm.length;i+=320){let sum=0,n=0;for(let j=i;j<Math.min(i+320,pcm.length);j+=2){sum+=(pcm.readInt16LE(j)/32768)**2;n++;}if(Math.sqrt(sum/Math.max(1,n))>.004)last=Math.min(i+320,pcm.length);}let phoneEnd=0;for(let i=0;i<cues.length-1;i++)if(cues[i].id!==0)phoneEnd=Math.max(phoneEnd,cues[i+1].time*1000);return Math.min(pcm.length/32,Math.max(last/32,phoneEnd)+60);}
async function valid(asset){try{const base=asset.source==='formal'?path.resolve('data/curriculum/cloud-runtime/releases/'+old.release):root;const wav=await fs.readFile(path.resolve(base,asset.file));return wav.length===asset.size&&hash(wav)===asset.sha256&&asset.cues?.length>1;}catch{return false;}}
const englishTexts=new Set(pilotLessons.flatMap(l=>l.steps.flatMap(s=>[...s.script,...s.afterScript,...(s.reviewScript||[])].filter(a=>a.language==='en').map(a=>a.text))));
for(const s of pilotLessons.flatMap(l=>l.steps))for(const answer of s.answers)englishTexts.add(answer);
for(const text of [...Object.keys(wordGuides),'an apple and a banana','an apple or a banana','although this is difficult','despite the difficulty','a banana','an apple','the difficulty'])englishTexts.add(text);
for(const l of pilotLessons){const formal=await read('data/curriculum/cloud-runtime/releases/'+old.release+'/teacher/'+l.id+'.json');for(const w of formal.actualWords)if(w.word.toLowerCase()!=='a')englishTexts.add(w.word);}
for(const text of englishTexts){
 let a=Object.values(old.assets).find(a=>a.language==='en'&&normalized(a.text)===normalized(text)&&a.voice!==403007);
 if(a&&!await valid(a))a=null;
 if(a){const wav=await fs.readFile(root+'/'+a.file);const end=boundary(wav,a.cues);if(end>a.cues.at(-1).time*1000+350)a=null;else a={...a,speechEndMs:end};}
 if(!a){const generated=await teachingAudio(/[.!?]$/.test(text)?text:text+'.',{voice:403008,language:'en'});const wav=await fs.readFile(path.join(cacheDir,generated.key+'.wav'));const result=await read(path.join(cacheDir,generated.key+'.alignment.json'));if(result.PronAccuracy<90||result.PronCompletion<.98||result.Words.some(w=>w.MatchTag!==0||w.PronAccuracy<80))throw Error('English quality: '+text);const digest=hash(wav);await fs.writeFile(root+'/audio/'+digest+'.wav',wav,{flag:'wx'}).catch(e=>{if(e.code!=='EEXIST')throw e;});a={id:'en-'+digest,text,language:'en',voice:403008,source:'pilot',file:'audio/'+digest+'.wav',sha256:digest,size:wav.length,cues:generated.cues,speechEndMs:boundary(wav,generated.cues)};await fs.writeFile(root+'/evidence/'+a.id+'.json',JSON.stringify({asset:a,assessment:result}));}
 assets[a.id]=a;englishIds[text]=a.id;
}
const utterances=new Set([...pilotLessons.flatMap(l=>l.steps.flatMap(s=>[...s.script,...s.afterScript,...(s.reviewScript||[])].filter(a=>a.language==='zh').map(a=>a.text))),...Object.values(wordGuides),...Object.values(repairMessages),...Object.values(soundTips)]);
const texts=[...new Set([...utterances].flatMap(split))];
if(texts.some(t=>t.includes('老师')))throw Error('Unapproved self-reference');
const metrics={revision:pilotRevision,totalChinese:texts.length,reusedChinese:0,newTts:0,newSoe:0,newAsr:0,completed:0,startedAt:new Date().toISOString()};
await fs.writeFile(build+'/progress.json',JSON.stringify(metrics,null,2));
let cursor=0;
async function worker(){while(cursor<texts.length){
 const text=texts[cursor++],id='zh-'+hash(text),meta=root+'/evidence/'+id+'.json';
 let a=Object.values(old.assets).find(a=>a.language==='zh'&&a.text===text&&a.cueSource==='soe-mandarin-phone-timing');
 if(a&&!await valid(a))a=null;
 if(a){const wav=await fs.readFile(root+'/'+a.file);const end=boundary(wav,a.cues);if(end>a.cues.at(-1).time*1000+350)a=null;else a={...a,speechEndMs:end};}
 if(!a){try{const saved=await read(meta);a=saved.asset||saved;if(a.text!==text||!await valid(a)||a.cueSource!=='soe-mandarin-phone-timing')a=null;}catch{}}
 if(a)metrics.reusedChinese++;
 else {
  let accepted=false;
  for(let attempt=1;attempt<=3&&!accepted;attempt++){
   const checkpoint=build+'/'+id+'.json',wavFile=build+'/'+id+'.wav';let raw,result,recognized,wav;
   try{const saved=await read(checkpoint);wav=await fs.readFile(wavFile);if(saved.text!==text||saved.sha256!==hash(wav))throw Error();raw=saved.raw;result=saved.assessment;recognized=saved.recognition;}catch{}
   if(!raw){raw=await synthesize(text,{voice:403008});wav=raw.wav;delete raw.wav;metrics.newTts++;await fs.writeFile(wavFile,wav);}
   const persist=()=>fs.writeFile(checkpoint,JSON.stringify({text,sha256:hash(wav),raw,assessment:result,recognition:recognized}));
   await persist();
   if(!result){result=await assess(wav,{text,language:'zh',strictness:2});metrics.newSoe++;await persist();}
   const quality=result.PronAccuracy>=90&&result.PronCompletion>=.98&&chinese(result.Words.map(w=>w.Word).join(''))===chinese(text)&&result.Words.every(w=>w.MatchTag===0);
   if(!recognized){recognized=await recognize(wav,{engine:'16k_zh_en_2.0'});metrics.newAsr++;await persist();}
   if(!quality||chinese(recognized.text)!==chinese(text)){
    await fs.writeFile(build+'/'+id+'.rejected.json',JSON.stringify({attempt,text,heard:recognized.text,accuracy:result.PronAccuracy,completion:result.PronCompletion,sha256:hash(wav)}));
    await fs.unlink(checkpoint);await fs.unlink(wavFile);
    if(attempt===3)throw Error('Narration failed three times: '+text+' | '+recognized.text);
    continue;
   }
   const {duration}=readWave(wav);const cues=mandarinVisemes(result,duration);const digest=hash(wav);
   await fs.writeFile(root+'/audio/'+digest+'.wav',wav,{flag:'wx'}).catch(e=>{if(e.code!=='EEXIST')throw e;});
   a={id,text,voice:403008,language:'zh',source:'pilot',file:'audio/'+digest+'.wav',sha256:digest,size:wav.length,cues,cueSource:'soe-mandarin-phone-timing',speechEndMs:boundary(wav,cues),quality:{accuracy:result.PronAccuracy,completion:result.PronCompletion}};
   await fs.writeFile(meta,JSON.stringify({asset:a,assessment:result,recognition:recognized},null,2));accepted=true;
  }
 }
 if(!a.speechEndMs)a={...a,speechEndMs:boundary(await fs.readFile(root+'/'+a.file),a.cues)};
 assets[a.id]=a;metrics.completed++;await fs.writeFile(build+'/progress.json',JSON.stringify(metrics,null,2));console.log(JSON.stringify({done:metrics.completed,total:metrics.totalChinese,newTts:metrics.newTts,reused:metrics.reusedChinese}));
}}
await Promise.all(Array.from({length:4},worker));
for(const text of utterances)narrationIds[text]=split(text).map(t=>assets['zh-'+hash(t)]?.id||Object.values(assets).find(a=>a.text===t&&a.language==='zh')?.id);
const idsFor=script=>script.flatMap(a=>a.language==='en'?[englishIds[a.text]]:narrationIds[a.text]);
const lessons=pilotLessons.map(l=>({...l,steps:l.steps.map(s=>({...s,beforeAudio:idsFor(s.script),afterAudio:idsFor(s.afterScript),reviewAudio:idsFor(s.reviewScript||[]),audio:s.models.map(t=>englishIds[t]),narration:idsFor(s.script.filter(a=>a.language==='zh'))[0]}))}));
for(const l of lessons)for(const s of l.steps)if([...s.beforeAudio,...s.afterAudio].some(id=>!assets[id]))throw Error('Missing audio in '+s.id);
const current={schema:'snow-speaks.teaching-pilot/1',presentation:'stable-board/1',revision:pilotRevision,release:old.release,lessons,assets,englishIds,narrationIds,guides:wordGuides,messages:repairMessages};
await fs.writeFile(root+'/current.pending.json',JSON.stringify(current,null,2));
metrics.completedAt=new Date().toISOString();metrics.assets=Object.keys(assets).length;
await fs.writeFile(root+'/audio-build-check.json',JSON.stringify(metrics,null,2));console.log(JSON.stringify(metrics));
