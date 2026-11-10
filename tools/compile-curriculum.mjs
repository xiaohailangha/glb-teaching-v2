import fs from 'node:fs';
import crypto from 'node:crypto';
const root='scene-preview/assets/avatar',plan=JSON.parse(fs.readFileSync('data/curriculum/plan.json','utf8'));
const prompts=new Map(),catalog=[];
function clip(text,language='en'){const id='c96_'+crypto.createHash('sha256').update(language+':'+text).digest('hex').slice(0,20);prompts.set(id,{text,language});return id;}
for(const item of JSON.parse(fs.readFileSync('data/curriculum/supporting-vocabulary.json','utf8')))clip(item.text);
const options=[{id:'attempt',label:'我读好了'},{id:'help',label:'再听示范'}];
const legacy=JSON.parse(fs.readFileSync('data/course-catalog.json','utf8'));
for(const group of plan.categories){
 const written=JSON.parse(fs.readFileSync('data/curriculum/'+group.id+'.json','utf8'));
 for(const slot of group.lessons){
  const source=written.find(c=>c.id===slot.id);if(!source)throw Error('Missing authored lesson: '+slot.id);
  if(typeof source.coverTitle!=='string'||source.coverTitle.split('\n').length!==2)throw Error('Missing lesson cover title: '+slot.id);
  const title=String(slot.order).padStart(2,'0')+' · '+slot.title,stages=[],word=source.vocabulary[0].text.toLowerCase();
  const add=row=>stages.push({chapter:slot.title,word,...row});
  const model=(id,item)=>add({id,phase:'demonstrate',display:item.text,text:item.meaning,clip:clip(item.text),speechText:item.text});
  const practice=(id,item,phase='listen',text=item.meaning)=>add({id,phase,display:item.text,text,practiceClip:clip(item.text),speechText:item.text,hide:phase==='recall',options});
  add({id:'intro',phase:'introduce',display:title,text:source.goal,clip:clip(source.goal,'zh')});
  if(source.review){for(const [i,item] of source.vocabulary.entries())practice('review_word_'+i,item,'recall','回想学过的表达：'+item.meaning);}
  else for(const [i,item] of source.vocabulary.entries()){
   const meaning=item.meaning.split('；')[0];
   add({id:'word_'+i+'_meaning',phase:'meaning',word:item.text.toLowerCase(),display:item.text,text:item.meaning,clip:clip(meaning,'zh')});
   model('word_'+i+'_model',item);stages.at(-1).word=item.text.toLowerCase();
   practice('word_'+i,item);stages.at(-1).word=item.text.toLowerCase();
  }
  for(const [i,item] of source.chunks.entries()){model('chunk_'+i+'_model',item);practice('chunk_'+i,item);}
  for(const [i,item] of source.sentences.entries()){model('sentence_'+i+'_model',item);practice('sentence_'+i,item);}
  for(let i=0;i<2;i++){
   const target=source.vocabulary[i],answers=source.vocabulary.map((v,n)=>({id:'answer_'+n,label:v.meaning.split('；')[0]}));
   add({id:'identify_'+i+'_cue',phase:'choice',display:'听音辨意',text:'先听声音，再选择意思。',clip:clip(target.text),hide:true});
   add({id:'identify_'+i,phase:'choice',display:'听音辨意',text:'刚才听到的表达是什么意思？',word:target.text.toLowerCase(),answer:'answer_'+i,practiceClip:clip(target.text),speechText:target.text,hide:true,options:[...answers.slice(i+1),...answers.slice(0,i+1)]});
  }
  for(const [i,item] of source.chunks.entries())practice('recall_chunk_'+i,item,'recall','不看英文，请表达：'+item.meaning);
  for(const [i,item] of source.sentences.entries())practice('transfer_'+i,item,'recall','情境练习：'+source.scenario+'\n这一句请表达：'+item.meaning);
  add({id:'summary',phase:'finish',display:'本节学习记录',text:'本节课我们就学到这里。',options:[]});
  if(source.teachingStages)stages.splice(0,stages.length,...structuredClone(source.teachingStages));
  const course={id:slot.id,title,category:group.id,goal:source.goal,prerequisites:source.prerequisites,scenario:source.scenario,stages};
  fs.writeFileSync(`${root}/courses/${slot.asset}.json`,JSON.stringify(course,null,2)+'\n');
  catalog.push({id:slot.id,asset:slot.asset,title,goal:source.goal,category:group.id,coverTitle:source.coverTitle,example:source.sentences[0].text,unit:group.order,status:'published',prerequisites:source.prerequisites,version:crypto.createHash('sha256').update(JSON.stringify(course)).digest('hex').slice(0,12),stages});
 }
}
if(catalog.length!==96||new Set(catalog.map(c=>c.id)).size!==96)throw Error('Expected 96 unique courses');
if(new Set(catalog.map(c=>c.coverTitle.trim().toLowerCase())).size!==96)throw Error('Each lesson must have a distinct English cover title');
for(const g of plan.categories)if(catalog.filter(c=>c.category===g.id).length<12)throw Error('Incomplete category');
fs.mkdirSync('work/curriculum',{recursive:true});
fs.writeFileSync('work/curriculum/prompts.json',JSON.stringify(Object.fromEntries(prompts),null,2));
fs.writeFileSync('work/curriculum/catalog-draft.json',JSON.stringify({release:'首批 8 类 · 96 节',types:plan.categories.map(g=>({id:g.id,title:g.title,courseIds:g.lessons.map(c=>c.id)})),courses:catalog,lexicon:legacy.lexicon,phonemes:legacy.phonemes},null,2));
console.log(`Compiled ${catalog.length} lesson drafts, ${prompts.size} unique prompts. Not published; audio and editorial gates remain.`);
