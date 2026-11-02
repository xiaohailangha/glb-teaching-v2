import fs from 'node:fs';
import crypto from 'node:crypto';
import {readWave} from '../services/tencent-speech.mjs';
import {audioHash,sameSpeech,audioQualityVersion} from '../services/course-audio-quality.mjs';
const read=p=>JSON.parse(fs.readFileSync(p,'utf8')),root='scene-preview/assets/avatar';
const plan=read('data/curriculum/plan.json'),draft=read('work/curriculum/catalog-draft.json');
if(plan.categories.length!==8||draft.courses.length!==96)throw Error('Expected eight categories and 96 courses');
for(const g of plan.categories){
 if(g.lessons.length<12)throw Error('Category incomplete: '+g.id);
 const source=read('data/curriculum/'+g.id+'.json');
 for(const c of source)if(c.editorialStatus!=='second-pass-reviewed')throw Error('Editorial review missing: '+c.id);
}
const pending=[],checks=[];
function checkCandidate(key,item,directory){
 const metadata=read(directory+'/'+key+'.json'),wav=fs.readFileSync(directory+'/'+key+'.wav'),actual=audioHash(wav),duration=readWave(wav).duration;
 if(metadata.quality?.version!==audioQualityVersion||metadata.sha256!==actual||metadata.quality.sha256!==actual||!sameSpeech(item.text,metadata.text,item.language||'en'))throw Error('Unverified candidate: '+key);
 if(item.language!=='zh'&&/\b(read|close|excuse)\b/i.test(item.text)){
  if(!metadata.sourcePhones?.length)throw Error('Missing pronunciation evidence: '+key);
  for(const row of metadata.sourcePhones){const word=row.word.toLowerCase();if(word==='read'&&!row.phones.includes('iy')||['close','excuse'].includes(word)&&row.phones.at(-1)!=='z')throw Error('Wrong verb pronunciation: '+key);}
 }
 if(Math.abs(duration-metadata.duration)>.001||!Array.isArray(metadata.cues)||metadata.cues.some((c,i,a)=>!Number.isFinite(c.time)||c.time<0||c.time>duration+.001||(i>0&&c.time<a[i-1].time)))throw Error('Audio timing invalid: '+key);
 pending.push({key,metadata,wav});checks.push({key,sha256:actual,duration,qualityVersion:metadata.quality.version});return metadata;
}
// Validate everything before changing a single production manifest.
const newManifest={};
for(const [key,item]of Object.entries(read('work/curriculum/prompts.json')))newManifest[key]=checkCandidate(key,item,'work/curriculum/new-audio');
const oldManifests={};
for(const name of fs.readdirSync(root+'/audio').filter(n=>n.endsWith('.json')&&n!=='curriculum-prompts.json')){
 const manifest=read(root+'/audio/'+name);let changed=false;
 for(const [key,item]of Object.entries(manifest))if(item?.text&&/[a-z]/i.test(item.text)&&!/[\u3400-\u9fff]/.test(item.text)&&!['phoneme','group'].includes(item.kind)){
  manifest[key]={...item,...checkCandidate(key,item,'work/curriculum/audio-candidates')};changed=true;
 }
 if(changed)oldManifests[name]=manifest;
}
for(const item of pending)fs.writeFileSync(root+'/audio/'+item.key+'.wav',item.wav);
fs.writeFileSync(root+'/audio/curriculum-prompts.json',JSON.stringify(newManifest,null,2)+'\n');
for(const [name,manifest]of Object.entries(oldManifests))fs.writeFileSync(root+'/audio/'+name,JSON.stringify(manifest,null,2)+'\n');
const audio={};
for(const name of fs.readdirSync(root+'/audio').filter(n=>n.endsWith('.json'))){
 for(const [key,item]of Object.entries(read(root+'/audio/'+name)))if(item?.text)audio[key]={text:item.text,duration:item.duration,url:'/scene/assets/assets/avatar/audio/'+key+'.wav',sha256:audioHash(fs.readFileSync(root+'/audio/'+key+'.wav'))};
}
for(const course of draft.courses){
 const cover=`cover-${course.asset}.svg`;
 if(!fs.existsSync(root+'/images/'+cover))throw Error('Missing course cover: '+cover);
 course.coverImage='/scene/assets/assets/avatar/images/'+cover;
 const data=read(root+'/courses/'+course.asset+'.json');
 course.stages=data.stages.map(s=>{
  const key=s.clip||s.practiceClip;
  if(key&&!audio[key])throw Error('Missing stage audio: '+course.id+'/'+s.id);
  return {...s,audio:key?audio[key]:null,image:s.picture?'/scene/assets/assets/avatar/images/'+s.picture+'.svg':null};
 });
 course.version=crypto.createHash('sha256').update(JSON.stringify(data)).digest('hex').slice(0,12);
}
draft.lexicon=read('data/curriculum/lexicon.json').map(w=>{
 if(!audio[w.clip])throw Error('Missing lexicon audio: '+w.word);
 return {...w,audio:audio[w.clip],courses:draft.courses.filter(c=>c.stages.some(s=>new RegExp('\\b'+w.word+'\\b','i').test(s.display||s.speechText||''))).map(c=>c.title)};
});
draft.phonemes=[...fs.readFileSync('scene-preview/lib/features/lesson/domain/ipa_sounds.dart','utf8').matchAll(/'([^']+)': '([^']+)'/g)].map(m=>({symbol:m[1],url:'/scene/assets/assets/avatar/audio/phoneme_'+m[2]+'.wav'}));
draft.quality={schema:1,editorial:'second-pass-reviewed',audioVersion:audioQualityVersion,audioCount:checks.length,checkedAt:new Date().toISOString()};
fs.writeFileSync('data/course-catalog.json',JSON.stringify(draft,null,2)+'\n');
const files=[];
for(const folder of ['audio','courses','images'])for(const name of fs.readdirSync(root+'/'+folder).sort())if(/\.(wav|json|svg|txt)$/.test(name)){const file=root+'/'+folder+'/'+name;files.push({path:file,sha256:audioHash(fs.readFileSync(file))});}
fs.writeFileSync('data/curriculum/release-quality.json',JSON.stringify({schema:1,catalogHash:audioHash(fs.readFileSync('data/course-catalog.json')),checkedAt:new Date().toISOString(),courseCount:96,categoryCount:8,editorial:'second-pass-reviewed',audio:checks,files},null,2)+'\n');
console.log('Finalized 96 reviewed courses and '+checks.length+' verified English/Chinese audio candidates. Ready for release checks, not activated.');
