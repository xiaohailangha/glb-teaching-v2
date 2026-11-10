import {pilotLessons,wordGuides,repairMessages} from './teaching-pilot-v4-content.mjs';
export {pilotLessons,wordGuides,repairMessages};
export const pilotRevision='teacher-plan-20261106-v5';
const make=(id,part,title,body,display='',models=[],answers=[],extra={})=>({id,part,title,body,display,models,answers,supported:true,...extra});
const [basic,advanced]=pilotLessons;
const goal=basic.steps[0];goal.display='an apple and a banana\nan apple or a banana';goal.translation='苹果和香蕉，两样都要\n苹果或者香蕉，任意一种都可以';goal.models=['an apple and a banana','an apple or a banana'];goal.body='今天学两个连接词。第一个把两样连接起来，第二个表示不同选择。在今天的例子里，要分清两样都要和任选一种。先听两个短语，不用急着回答。';
basic.steps.find(s=>s.id==='and-read').translation='我想要一个苹果和一根香蕉。';basic.steps.find(s=>s.id==='or-read').translation='我想要苹果或者香蕉，任意一种都可以。';
basic.steps.find(s=>s.id==='or-use').scaffold='I want an apple … a banana.';
basic.steps.find(s=>s.id==='or-use').reduceAfter=['and-read','or-read'];
basic.steps.splice(3,0,make('rhythm','句子里的声音','连接词可以轻读','放进句子以后，连接词可以读轻一些。意思清楚，衔接自然就可以，不用每个词都一样重。'));
basic.steps.splice(basic.steps.length-1,0,make('variation','只在顺利时再练一次','换一个已经读过的词','这次把两种水果前后换一换，意思还是任意一种都可以。看着完整提示说。','I want a banana or an apple.',[],['I want a banana or an apple.'],{condition:{smooth:['and-read','or-read','or-use'],words:['apple','banana']},transfer:true}));
const word=(id,word,meaning)=>make(id,'补充陌生词',word+'：'+meaning,'先认识这里用到的词。'+meaning+'。先听声音，再看着读一遍。',word,[word],[word],{condition:{unknown:word}});
let at=advanced.steps.findIndex(s=>s.id==='although-read');advanced.steps.splice(at,0,word('prepare-difficult','difficult','困难的'));
at=advanced.steps.findIndex(s=>s.id==='despite-read');advanced.steps.splice(at,0,word('prepare-difficulty','difficulty','困难这个名词'));
const d=advanced.steps.find(s=>s.id==='despite-read');d.translation='尽管有困难，我还是可以试试。';d.body='上面是一件完整的事，下面是表示这个困难的名词短语。换开头时，后面的结构也要跟着换。先听短语和完整句，再看着说。';
at=advanced.steps.findIndex(s=>s.id==='despite-read')+1;advanced.steps.splice(at,0,
 make('despite-convert','第一段 · 结构转换','换开头，后面也一起换','现在把第一句的开头换成尽管，后面的结构也一起换好。完整表达就在下面，看着说即可。','Despite the difficulty, I can try.',[],['Despite the difficulty, I can try.'],{contrast:['Although this is difficult, I can try.','Despite the difficulty, I can try.']}),
 make('part-one-end','第一段小结','留意开头后面的结构','这一段里，虽然的后面用了完整小句，尽管的后面用了名词短语。换词时也要留意后面的结构。可以随时离开课程，下次接着学。'));
advanced.steps.find(s=>s.id==='although-read').translation='虽然这件事有困难，我还是可以试试。';
advanced.steps.find(s=>s.id==='however-read').body='第一句先说有困难。第二句表达转折，说自己可以尝试。意思有联系，这次组织成两句话。先听示范，再看着说。';
advanced.steps.find(s=>s.id==='however-read').contrast=['This is difficult.','However, I can try.'];
advanced.steps.find(s=>s.id==='nonetheless').body='这个词表示尽管如此，强调即使有前面说的情况，后面的意思仍然成立。在较正式的表达中也会遇到。先听，可以跟读，也可以直接用右箭头继续。';
advanced.steps.find(s=>s.id==='nonetheless').optionalWindowMs=4500;
const use=advanced.steps.find(s=>s.id==='supported-use');use.preferSuccessful=['although-read','however-read','despite-read'];
at=advanced.steps.findIndex(s=>s.id==='supported-use')+1;advanced.steps.splice(at,0,make('part-two-end','第二段小结','先用最熟悉的一种','你练习了用不同方式表达转折。先使用自己最熟悉的一种，其他说法以后再逐步熟练。可以随时离开课程，下次接着学。'));
at=advanced.steps.findIndex(s=>s.id==='against-read');advanced.steps.splice(at,0,word('prepare-proposal','proposal','提案或者建议'));
at=advanced.steps.findIndex(s=>s.id==='against-read')+1;advanced.steps.splice(at,0,make('against-example','完整用法','放进句子里听','这里反对的对象是这项提案。听一个完整例子，不用额外再读一遍。','I am against the proposal.',['I am against the proposal.']));
at=advanced.steps.findIndex(s=>s.id==='except-use')+1;advanced.steps.splice(at,0,
 make('except-example','完整用法','除我之外，其他人都能去','听一个完整例子。这里把我排除在范围之外，不要求背下整句。','Everyone can go except me.',['Everyone can go except me.']),
 make('relations','第三段 · 语言对照','对象、群体和例外','这三个短语分别说明反对的对象，所在群体，以及排除的对象。只复习这次还不稳定的一处，前面顺利就直接结束。','',[],[],{contrast:['against the proposal：反对什么','among friends：在什么群体之中','except me：把谁排除在外']}),
 make('targeted-review','只复习需要的一处','看着提示，再说这一处','只复习刚才还不稳定的这一处。看着完整提示说一次。','against the proposal',[],['against the proposal','among friends','except me'],{condition:{review:['against-read','among-phrase','except-use']},reviewTarget:true}));
repairMessages.assisted='这一处先留作复习。现在看着完整提示，把刚才的意思连起来说。';
repairMessages.summaryFollow='你完成了示范后的跟读，具体项目已经列在屏幕上。';
repairMessages.summarySupported='你已经借助文字提示表达了刚才的意思，屏幕列出了本次使用过的表达。';
repairMessages.summaryTransfer='你还完成了一次更换已学词语的练习。';
repairMessages.summaryReview='屏幕标出的词语或结构还需要复习，下次先从这些位置开始。';
advanced.steps[0].body='本课分三段。先学虽然与尽管的结构，再学两句话之间的转折，最后说清对象、群体和例外。一段一段来，不用一次记住所有说法。';
advanced.steps[0].display='让步结构 / 转折表达 / 对象与范围';
for(let i=0;i<advanced.steps.length;i++)advanced.steps[i].part=i<=advanced.steps.findIndex(s=>s.id==='part-one-end')?'第一段 · although / though / despite':i<=advanced.steps.findIndex(s=>s.id==='part-two-end')?'第二段 · however / nonetheless':'第三段 · 对象、群体和例外';
