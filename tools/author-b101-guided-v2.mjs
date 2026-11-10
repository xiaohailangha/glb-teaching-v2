import fs from 'node:fs';
import crypto from 'node:crypto';
const read=p=>JSON.parse(fs.readFileSync(p,'utf8'));
const write=(p,x)=>fs.writeFileSync(p,JSON.stringify(x,null,2)+'\n');
const sample=read('data/curriculum/sample.json');
const checks=read('data/curriculum/checks.json').filter(c=>c.kind!=='teaching');
const jobs=new Map();
function voice(text,language='zh'){
 const id='B102-'+crypto.createHash('sha256').update(language+':'+text).digest('hex').slice(0,16);
 jobs.set(id,{id,text,language});return id;
}
const specs=[
 {id:'B1.01-L01',intro:'今天一起学习见面问好和离开道别。先听意思，再跟着我说。',
 words:[['hello','你好'],['hi','嗨，也是在打招呼'],['goodbye','再见'],['bye','再见，更简短的说法'],['welcome','欢迎，迎接来到这里的人']],
 turns:[['C01','hello','我们刚见面，和我打个招呼。'],['C02','bye','我们要离开了，和我道个别。']]},
 {id:'B1.01-L02',intro:'今天学习回答近况问候。我们只练两种简短回应。',
 words:[['good','好，表示现在感觉不错'],['ok','还好，表示现在状态还可以']],
 listening:[['how','你最近怎么样？这是在关心你的近况。']],
 turns:[['C04','good','今天感觉不错，用刚学过的话回应我。']]},
 {id:'B1.01-L03',intro:'今天学习我和你，再介绍自己的名字。练习时，我们一直用同一个名字。',
 words:[['i','我，说到自己时使用'],['you','你，说到对方时使用'],['me','我，可以用来确认对方是不是在叫自己']],
 chunks:[[null,'我是',"I'm"]],sentences:[['im-li','我是李。']],
 turns:[['C06','im-li','今天你扮演小李，向我介绍自己。']]},
 {id:'B1.01-L04',intro:'今天继续介绍名字。我们还是扮演小李。',
 words:[[null,'我的','my'],[null,'你的','your'],['name','名字']],
 chunks:[['my-name','我的名字'],['your-name','你的名字']],
 sentences:[['my-name-li','我的名字是李。']],listening:[['your-name-q','你的名字呢？这是在询问你的名字。']],
 turns:[['C08','my-name-li','继续扮演小李，告诉我你的名字。']]},
 {id:'B1.01-L05',intro:'今天学习介绍来自哪里。只用中国这个地方练习，不更换国家。',
 words:[['country','国家'],['from','来自'],['where','哪里'],['china','中国']],
 chunks:[[null,'来自中国','from China']],sentences:[['from-china','我来自中国。']],
 listening:[['where-from','你来自哪里？这是在询问你来自的地方。']],
 turns:[['C10','from-china','你扮演来自中国的小李，和我说说你来自哪里。']]},
 {id:'B1.01-R',intro:'这一课不学新内容。我们用已经说过的话，完成一次简单的见面。',
 sentences:[['hello','你好'],['my-name-li','我的名字是李。'],['from-china','我来自中国。'],['bye','再见']],
 turns:[['U01','hello','和我打个招呼。'],['U02','my-name-li','你还是小李，介绍一下自己。'],['U03','from-china','你还是来自中国，说说你来自哪里。'],['U04','bye','我们先聊到这里，和我道个别。']]},
];
for(const spec of specs){
 const steps=[];let n=0;
 const add=(phase,audio,instruction,display='',extra={})=>steps.push({id:`${spec.id}-V2-${++n}`,course:spec.id,phase,audio,instruction,display,...extra});
 add('开场',voice(spec.intro),spec.intro,'');
 const targets=[];
 for(const [group,items] of [['单词',spec.words||[]],['短语',spec.chunks||[]],['句子',spec.sentences||[]]]){
  for(const [key,meaning,english] of items){
   const audio=key?'B101-'+key:voice(english,'en');
   const text=english||sample.audio.find(a=>a.id===audio).text;
   const clean=meaning.replace(/[。！？]$/,'');
   add('释义',voice(meaning),meaning,text,{group});
   add('示范',audio,clean,text,{group});
   const check=`T2-${spec.id}-${n}`;
   checks.push({id:check,course:spec.id,kind:'teaching',audio:[],prompt:clean,answers:[text],hint:text});
   add('跟读','',clean,text,{check,model:audio,supported:true,group});
   targets.push({audio,text,meaning,check});
  }
 }
 for(const [key,meaning] of spec.listening||[]){
  const text=sample.audio.find(a=>a.id==='B101-'+key).text;
  add('释义',voice(meaning),meaning,text);
  add('理解','B101-'+key,meaning,text);
 }
 // Reuse only explicitly taught language. Support tap/replay remains available.
 for(const [check,key,prompt] of spec.turns){
  const audio='B101-'+key,text=sample.audio.find(a=>a.id===audio).text;
  add('带练提示',voice(prompt),prompt,'');
  const teaching=targets.find(t=>t.audio===audio);
  if(teaching)add('有提示表达','',prompt,text,{check:teaching.check,model:audio,supported:true});
  add('情境','',prompt,'',{check,model:audio,supported:false});
 }
 add('收束',voice('本节课我们就学到这里。你可以点单词，再听一听。'),'本节课我们就学到这里。');
 sample.guidedLessons[spec.id]=steps;
}
sample.audio=sample.audio.filter(a=>!a.id.startsWith('B102-'));
sample.audio.push(...jobs.values());
write('data/curriculum/sample.json',sample);write('data/curriculum/checks.json',checks);
fs.mkdirSync('work/b101-guided-v2',{recursive:true});
write('work/b101-guided-v2/jobs.json',[...jobs.values()]);
console.log(`Authored six lessons; ${jobs.size} narrated teaching assets to validate.`);
