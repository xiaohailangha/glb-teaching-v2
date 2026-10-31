import fs from 'node:fs';
import crypto from 'node:crypto';
const read=p=>fs.readFileSync(p,'utf8');
const root='scene-preview/assets/avatar';
const catalog=read('scene-preview/lib/features/lesson/domain/course_catalog.dart');
const audio={};
for(const name of fs.readdirSync(root+'/audio').filter(n=>n.endsWith('.json'))){
 const data=JSON.parse(read(root+'/audio/'+name));
 for(const [id,item] of Object.entries(data))if(item&&typeof item==='object'&&item.text){
   // The runtime resolves bundled clips by manifest key.
   const file=root+'/audio/'+id+'.wav';
   audio[id]={text:item.text,duration:item.duration,url:fs.existsSync(file)?'/scene/assets/assets/avatar/audio/'+id+'.wav':null};
 }
}
const courses=[...catalog.matchAll(/CourseInfo\(\s*'([^']+)',\s*'([^']+)',\s*'([^']+)',\s*'([^']+)'/g)].map((m,i)=>{
 const data=JSON.parse(read(`${root}/courses/${m[2]}.json`));
 const stages=data.stages.map(s=>({...s,audio:audio[s.clip||s.practiceClip]||null,image:s.picture?`/scene/assets/assets/avatar/images/${s.picture}.svg`:null}));
 return {id:m[1],asset:m[2],title:m[3],goal:m[4],unit:Math.floor(i/4)+1,status:'published',version:crypto.createHash('sha256').update(JSON.stringify(data)).digest('hex').slice(0,12),stages};
});
const planned=['问候与名字','来自哪里','喜好','认识新朋友','吃喝','时间','日常活动','我的一天'];
planned.forEach((title,i)=>courses.push({id:`planned-${i+9}`,title:`${String(i+9).padStart(2,'0')} · ${title}`,unit:Math.floor(i/4)+3,status:'planned',stages:[],goal:'按现有课程规划继续开发'}));
const lexicon=[...read('scene-preview/lib/features/lesson/domain/course_lexicon.dart').matchAll(/'([^']+)':\s*\(\s*clip:\s*'([^']+)',\s*ipa:\s*'([^']+)',\s*meaning:\s*'([^']+)'/g)].map(m=>({word:m[1],ipa:m[3],meaning:m[4],audio:audio[m[2]]||null,courses:courses.filter(c=>c.stages.some(s=>new RegExp(`\\b${m[1]}\\b`,'i').test(s.display||s.speechText||''))).map(c=>c.title)}));
const phonemes=[...read('scene-preview/lib/features/lesson/domain/ipa_sounds.dart').matchAll(/'([^']+)': '([^']+)'/g)].map(m=>({symbol:m[1],url:'/scene/assets/assets/avatar/audio/phoneme_'+m[2]+'.wav'}));
fs.mkdirSync('data',{recursive:true});
fs.writeFileSync('data/course-catalog.json',JSON.stringify({release:'r21 · 成人 01–08',courses,lexicon,phonemes},null,2));
console.log(`Exported ${courses.length} course entries and ${lexicon.length} words.`);
