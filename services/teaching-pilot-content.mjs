import fs from 'node:fs';
import path from 'node:path';
import {projectRoot} from './storage-paths.mjs';
export const pilotRevision='stable-teaching-20261110-v1';
export const approvedDesign=JSON.parse(fs.readFileSync(process.env.TEACHING_PILOT_DESIGN||path.join(projectRoot,'data/teaching-pilot/design.json'),'utf8'));
const english=s=>/^[A-Za-z][A-Za-z\s',.!?+/:;…-]*$/.test(s);
// Parse the approved line structure, never the currently playing recording.
export function boardFor(screen){
 const blocks=[];
 for(const group of screen.split(/\n\s*\n/)){
  const lines=group.split('\n').map(x=>x.trim()).filter(Boolean);if(!lines.length)continue;
  if(lines.some(x=>x.includes('[')))continue;
  let i=0;
  while(i<lines.length){
   if(/^[A-Za-z]+$/.test(lines[i])&&/^\/[^/]+\/$/.test(lines[i+1]||'')){
    const word=lines[i],showWord=blocks.length>0;
    if(!showWord)blocks.push({kind:'english',role:'word',text:word});
    const last=blocks.at(-1);
    if(last?.kind==='pronunciations'&&last.showWords===showWord)last.words.push(word);
    else blocks.push({kind:'pronunciations',words:[word],showWords:showWord});
    i+=2;continue;
   }
   if(english(lines[i])){
    const words=[];while(i<lines.length&&english(lines[i])&&!/^\/[^/]+\/$/.test(lines[i])&&!(words.length&&/^\/[^/]+\/$/.test(lines[i+1]||'')))words.push(lines[i++]);
    const meaning=[];while(i<lines.length&&!english(lines[i])&&!/^\/[^/]+\/$/.test(lines[i]))meaning.push(lines[i++]);
    const text=words.join(' ');
    if(meaning.length&&(!blocks.length||blocks.at(-1)?.kind==='pair'))blocks.push({kind:'pair',text,meaning:meaning.join('')});
    else {blocks.push({kind:'english',role:blocks.length?'context':'target',text});if(meaning.length)blocks.push({kind:'caption',text:meaning.join('')});}
   }else{blocks.push({kind:blocks.some(b=>['meaning','caption','pair'].includes(b.kind))?'note':'meaning',text:lines[i++]});}
  }
 }
 return blocks;
}
const answers={A02:['and'],A03:['I want an apple and a banana.'],A04:['or'],A05:['I want an apple or a banana.'],A06:['I want an apple and a banana.'],A07:['I want a banana or an apple.'],B02:['difficult'],B03:['Although this is difficult, I can try.'],B04:['though'],B05:['difficulty'],B06:['despite the difficulty'],B08:['Despite the difficulty, I can try.'],B10:['This is difficult. However, I can try.'],B11:['nonetheless'],B13:['Although this is difficult, I can try.','Though this is difficult, I can try.','Despite the difficulty, I can try.','This is difficult. However, I can try.','This is difficult. Nonetheless, I can try.'],B15:['proposal'],B16:['against the proposal'],B17:['friends'],B18:['among friends'],B19:['except me'],B20:['against the proposal','among friends','except me']};
const focus={A01:['and','or'],A02:['and'],A03:['and'],A04:['or'],A05:['or'],A06:['and','or'],A07:['or'],B02:['difficult'],B03:['although'],B04:['though'],B05:['difficulty'],B06:['despite','difficulty'],B07:['this','is','difficult','the','difficulty'],B08:['despite','difficulty'],B09:['although','though','despite'],B10:['however'],B11:['nonetheless'],B12:['nonetheless'],B13:['although'],B15:['proposal'],B16:['against'],B17:['friends'],B18:['among'],B19:['except']};
const follow={A02:['这个声音可以了。现在把两样都要放进完整表达。'],A03:['两样都要，意思清楚了。放进句子以后，中间的连接词可以轻一些，整句连贯就可以，不用每个词都一样重。'],A04:['这个词在这里带出的是两种选择。水果不用重新记，接下来只换句子中间这一处。'],A05:['这次是任选一种，和刚才两样都要的意思分开了。下面我不先读英语，你按意思选一句来说。'],A06:['这次你是按两样都要的意思，选出了合适的表达。'],A07:['顺序换了，你仍然保留了任选一种的意思。'],B02:['这个词认识了。下面把有困难和还想试试放在同一句里。'],B03:['你把困难说出来了，也保留了后面还想尝试的意思。'],B04:['这里换了开头，后面的句子框架可以保留。'],B05:['现在这两个意思分开了：一个描述困难的，一个把困难当作一件事来说。接下来就用这个名词搭配。'],B06:['这个短语表示尽管有困难。现在和刚才的说法对照一下，看看后面为什么也要换。'],B08:['这里把前面的情况换成了这个困难，后面的想法可以保留。'],B10:['这里先说困难，再转到自己仍然可以尝试。组织成两句话，意思也能连起来。'],B13:['这个说法也能表达这里的意思。'],B17:['这个词认识了。下面把在朋友之中连起来说。'],B18:['这里说明的是处在什么群体之中。接下来再看，怎样把其中一个人排除在范围外。']};
export const repairMessages={and:'你刚才说的是任选一种。这次想表达两样都要，只调整中间这个连接词。',or:'你刚才说的是两样都要。这次任意一种都可以，只调整中间这个连接词。',despite:'后半句的想法可以保留。这里需要换的是尽管后面的部分：用这个困难，不要继续说这件事有困难。',among:'这次要说在朋友之中，先调整说明所在群体的这个词。',except:'这次要说除我之外，先调整表示排除的这个词。',wording:'先调整标出的这个词。听一次，再试这一处。',unclear:'这次声音没有确认清楚，不算读错。原来的提示留着，你准备好再说一次。',again:'这个词还需要听清楚。先听完整声音，再试这一处。',return:'这一处清楚了。现在放回刚才的完整表达，连起来说。',assisted:'这一处先留作复习。完整提示还在这里，这次可以借着提示完成。想先继续，也可以用右箭头。',summaryFollow:'这次已经跟着说过这些表达。',summarySupported:'这次也能看着提示，按意思使用其中一种表达。',summaryTransfer:'这次换过已经学过的词，仍然保留了原来的意思。',summaryReview:'需要帮助的具体位置已经留作复习。'};
export const wordGuides={and:'把这两个东西连在一起，表示两样都要。先听这个词。',or:'这里表示任意一种都可以。先听这个词。',although:'中间这个齿间音，舌尖轻放在上下齿之间，声带振动。',though:'先听完整声音，不在词尾另外加一个音节。',despite:'后面的音节重一些，先听完整词。',however:'中间的音节重一些，两边轻一些。',nonetheless:'先听完整声音，注意最后一个主要重读音节。',against:'后面的音节重一些，词尾连在词里。',friends:'结尾连在完整词里，不额外加一个音节。',among:'后面的音节重一些，词尾鼻音收住，不额外加元音。',except:'先听完整词，结尾不额外加一个音节。',apple:'第一个元音可以把嘴张开一些，舌位靠前。',banana:'中间的音节重一些，先听完整声音。',difficult:'先听完整词，把几个音节自然连起来。',difficulty:'先听完整词，把几个音节自然连起来。',proposal:'中间的主要音节重一些，先听完整词。'};
const part=id=>id[0]==='A'?'两样都要，还是任选一种':Number(id.slice(1))<=9?'第一段 · 有困难仍想试试':Number(id.slice(1))<=14?'第二段 · 换一种方式表达转折':'第三段 · 对象、群体和例外';
export const pilotLessons=approvedDesign.lessons.map(l=>({id:l.id,title:l.title,goal:l.goal,steps:l.stages.map(s=>{
 const target=answers[s.id]?.[0]??'';
 const row={id:s.id,part:part(s.id),title:s.title,body:s.speech.join(''),display:target,models:s.models,answers:answers[s.id]??[],board:boardFor(s.screen),focus:focus[s.id]??[],supported:true,script:[...s.speech.map(text=>({language:'zh',text})),...s.models.map(text=>({language:'en',text})),...(s.afterModel?[{language:'zh',text:s.afterModel}]:[])],afterScript:(follow[s.id]??[]).map(text=>({language:'zh',text})),summary:['A08','B21'].includes(s.id),holdAfter:['B09','B14'].includes(s.id),optional:s.id==='B11',success:'step-'+s.id};
 if(s.id==='B05')row.board=[{kind:'pair',text:'difficult',meaning:'困难的'},{kind:'pair',text:'difficulty',meaning:'困难'},{kind:'pronunciations',words:['difficulty'],showWords:false},{kind:'pair',text:'the difficulty',meaning:'这个困难'}];
 if(['B02','B05','B15','B17'].includes(s.id))row.condition={unknown:target};
 if(s.id==='A07'){row.condition={smooth:['A03','A05','A06'],words:['apple','banana']};row.transfer=true;}
 if(s.id==='B13')row.preferSuccessful=['B03','B10','B08','B04'];
 if(s.id==='B20'){row.reviewCandidates=['B16','B18','B19'];row.reviewTarget=true;row.reviewScript=[{language:'zh',text:'现在只复习还不稳定的这一处。看着对应的短语，完整说一次。'}];}
 for(const [id,text,meaning,intro,word]of [['B16','I am against the proposal.','我反对这项提议。','把它放进一句话，就是我反对这项提议。这句先听懂用法就可以。','against'],['B19','Everyone can go except me.','除了我，其他人都能去。','放进完整句子，就是除了我，其他人都能去。这次只听懂排除的是谁。','except']])if(s.id===id){row.afterScript=[{language:'zh',text:intro},{language:'en',text}];row.afterBoard=[{kind:'english',role:'target',text},{kind:'meaning',text:meaning},{kind:'pronunciations',words:[word],showWords:true}];}
 return row;
})}));

// Alternative prompts are authored lesson boards, not live-caption heuristics.
const complex=pilotLessons[1];
const expressionBoards=Object.fromEntries(['B03','B04','B08','B10','B12'].map(id=>{const step=complex.steps.find(s=>s.id===id);return [step.models.at(-1),step.board];}));
for(const id of ['B13','B14'])complex.steps.find(s=>s.id===id).expressionBoards=expressionBoards;
