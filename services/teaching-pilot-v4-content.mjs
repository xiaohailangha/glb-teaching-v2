// Two explicitly requested teaching trials. Separate from the immutable 555 archive.
export const pilotRevision='teacher-led-20261106-v4';
const card=(id,part,title,body,display='',models=[],answers=[],extra={})=>({id,part,title,body,display,models,answers,supported:true,...extra});
export const pilotLessons=[
 {id:'N26-U006-L04',title:'一起要，还是选一种',goal:'理解和使用 and / or',steps:[
  card('goal','认识两个连接词','今天学什么','今天学两个连接词。学完以后，就能说清楚：苹果和香蕉两样都要，还是任意一种都可以。'),
  card('and','认识两个连接词','and：和','第一个词表示和，可以把两样东西连起来。苹果和香蕉，两样都在这里。','and',['and'],[],{picture:'both',focus:['and']}),
  card('and-phrase','认识两个连接词','把两样连起来','一个苹果和一根香蕉。先听清中间的连接词，不用急着回答。','an apple and a banana',['an apple and a banana'],[],{picture:'both',focus:['and']}),
  card('or','认识两个连接词','or：或者','第二个词表示或者。在这个情境里，苹果或者香蕉，任意一种都可以。','or',['or'],[],{picture:'either',focus:['or']}),
  card('or-phrase','认识两个连接词','换一个词，意思就变了','一个苹果或者一根香蕉。和刚才对照，这次任意一种都可以。','an apple or a banana',['an apple or a banana'],[],{picture:'either',focus:['or']}),
  card('and-read','看着说','两样都要','现在放进完整句子。先听示范，再看着这句话说，两样都想要。','I want an apple and a banana.',['I want an apple and a banana.'],['I want an apple and a banana.'],{picture:'both',focus:['and']}),
  card('or-read','看着说','任意一种都可以','保留熟悉的句子，只换中间的连接词。先听示范，再看着说。','I want an apple or a banana.',['I want an apple or a banana.'],['I want an apple or a banana.'],{picture:'either',focus:['or']}),
  card('and-use','带着提示用','看着句子告诉对方','现在苹果和香蕉都要，用表示和的连接词。看着完整句子告诉对方。','I want an apple and a banana.',[],['I want an apple and a banana.'],{picture:'both',focus:['and']}),
  card('or-use','带着提示用','只决定中间的词','这次任意一种都可以。两个连接词都留给你作提示，选合适的词，把整句说出来。','I want an apple or a banana.',[],['I want an apple or a banana.'],{picture:'either',scaffold:'I want an apple … a banana.',supportNote:'and：和 · or：或者',focus:['or']}),
  card('closing','本课小结','今天已经练过了','这一课练习了两种表达：两样都要，和任意一种都可以。看过提示也算完成练习，需要帮助的地方会留作复习。','and：和   /   or：或者')
 ]},
 {id:'N26-U084-L01',title:'承认不同，再说想法',goal:'理解让步结构、反对对象与范围',steps:[
  card('goal','本课目标','分三小节，慢慢来','今天先学怎样承认困难，再表达自己的想法；然后说明反对的对象；最后说清所在范围和例外。我们分三小节来，提示会一直陪着你。'),
  card('although','一 · 有困难，仍愿意尝试','although：虽然','这个词表示虽然。先承认一种情况，再说后面的想法。先听清这个词。','although',['although']),
  card('although-meaning','一 · 有困难，仍愿意尝试','两部分，各说一件事','前半句承认这件事有困难，后半句说自己可以试试。先听完整表达。','Although this is difficult, I can try.',['Although this is difficult, I can try.'],[],{contrast:['Although this is difficult,','I can try.'],focus:['although']}),
  card('although-read','一 · 看着说','看着整句说','我们看着整句说，不需要背下来。卡在哪里，就只练那一小段。','Although this is difficult, I can try.',[],['Although this is difficult, I can try.'],{focus:['although']}),
  card('though','一 · 换一种说法','though：这里也表示虽然','开头也可以换成这个词。本课用的是同样的结构，其他部分不变。','Though this is difficult, I can try.',['though','Though this is difficult, I can try.'],[],{focus:['though']}),
  card('despite','一 · 讲清结构','despite：尽管','这个词也能表达尽管。但在本课这里，后面用名词短语来表示困难。先听这个词。','despite',['despite']),
  card('despite-structure','一 · 讲清结构','后面接什么，跟着变','上面是完整的小句，说这件事有困难；下面是名词短语，表示这个困难。换开头时，后面的结构也要跟着变。','Despite the difficulty, I can try.',['Despite the difficulty, I can try.'],[],{contrast:['although this is difficult','despite the difficulty'],focus:['despite','difficulty']}),
  card('despite-read','一 · 带着转换','看着提示，换成 despite','这一次专门练结构转换。前半部分换成表示尽管有困难的短语，后半句保留。完整提示就在这里。','Despite the difficulty, I can try.',[],['Despite the difficulty, I can try.'],{contrast:['although this is difficult','despite the difficulty'],focus:['despite','difficulty']}),
  card('however','一 · 连接两句话','however：然而','这个词表示然而。我们先把困难说完，再用下一句话表达转折。注意这里分成两句话。','This is difficult. However, I can try.',['however','This is difficult. However, I can try.'],[],{focus:['however']}),
  card('however-read','一 · 看着说','两句话，连着表达','看着这两句话，先承认有困难，再说自己可以尝试。','This is difficult. However, I can try.',[],['This is difficult. However, I can try.'],{focus:['however']}),
  card('nonetheless','一 · 换一种说法','nonetheless：尽管如此','这个词表示尽管如此，强调即使有刚才的困难，仍然可以尝试。先听词，再听它放进句子里。','This is difficult. Nonetheless, I can try.',['nonetheless','This is difficult. Nonetheless, I can try.'],[],{focus:['nonetheless']}),
  card('supported-use','一 · 带着提示用','选一种熟悉的说法','现在你想说：事情有困难，自己仍然可以试试。选一种熟悉的说法表达。完整例句留在这里，也可以点例句换一种提示。','Although this is difficult, I can try.',[],['Although this is difficult, I can try.','Though this is difficult, I can try.','Despite the difficulty, I can try.','This is difficult. However, I can try.','This is difficult. Nonetheless, I can try.'],{alternatives:true,focus:['although']}),
  card('against','二 · 反对的对象','against：反对','现在换一种讨论情况。这个词在本课表示反对，后面说明反对的对象。','against',['against']),
  card('against-read','二 · 看着说','反对这项提案','这个短语表示反对这项提案。先听示范，再看着短语说。','against the proposal',['against the proposal'],['against the proposal'],{focus:['against']}),
  card('friends','三 · 范围和例外','先认识 friends','先看朋友这个词的复数形式，表示多位朋友。词尾也要保留，先听它的声音。','friends',['friends']),
  card('among','三 · 范围和例外','among：在……之中','这个词表示在一个群体之中。在朋友之中，就是这个短语。先听示范，再看着说。','among friends',['among','among friends'],['among friends'],{focus:['among']}),
  card('except','三 · 范围和例外','except：除……之外','这个词表示除某个人或东西之外，把它排除在范围外。这个短语表示除我之外，先听示范。','except me',['except','except me'],[],{focus:['except']}),
  card('except-use','三 · 带着提示用','把我排除在外','这里表达除我之外。看着提示说，注意和刚才在朋友之中的意思区别。','except me',[],['except me'],{contrast:['among friends：在朋友之中','except me：除我之外'],focus:['except']}),
  card('closing','本课小结','按小节学完了','今天练习了三种关系：承认困难后继续表达；说明反对的对象；以及所在范围和例外。不需要把所有句子再读一遍。需要帮助的地方会保留。','although / despite / however\nagainst / among / except')
 ]}
];

// Every unfamiliar word now has its own model and supported oral turn before
// the phrase/sentence that uses it. Existing v1 trial history stays untouched.
const complex=pilotLessons.find(l=>l.id==='N26-U084-L01');
for(const s of pilotLessons[0].steps)if(['and','or'].includes(s.id)){s.answers=[s.id];s.title=s.id+' · 先读这个词';}
const wordLessons={
 although:'这个词表示虽然。先承认一种情况，再说后面的想法。先听这个词，然后看着跟读一遍。',
 though:'这个词在本课也表示虽然，和前面用同样的结构。先听这个词，再看着跟读。',
 despite:'这个词表示尽管。本课后面用名词短语表示困难。先听这个词，再看着跟读。',
 however:'这个词表示然而，用来表达转折。先把这个词读清楚，再放进两句话里。',
 nonetheless:'这个词表示尽管如此，强调即使有困难仍然可以尝试。先听这个词，再跟读一遍。',
 against:'这个词在本课表示反对，后面说明反对的对象。先听这个词，再看着跟读。',
 friends:'这个形式表示多位朋友，结尾保留复数的声音。先听完整词，再跟着读一遍。',
 among:'这个词表示在一个群体之中。先听这个词，再跟读，之后放进短语。',
 except:'这个词表示除某个人或东西之外，把它排除在范围外。先听这个词，再跟读。'
};
complex.steps=complex.steps.flatMap(s=>{
 if(s.id==='however-read')return [{...s,models:['This is difficult. However, I can try.']}];
 if(s.id==='except-use')return [{...s,models:['except me']}];
 if(!Object.hasOwn(wordLessons,s.id))return [s];
 const word=s.id,first={...s,title:word+' · 先读这个词',body:wordLessons[word],display:word,models:[word],answers:[word],focus:[word]};
 if(['though','nonetheless'].includes(word))return [first,card(word+'-example',s.part,'再放进完整表达','这个词读过了，现在放进完整表达里听一遍。',s.display,[s.display],[],{focus:[word]})];
 if(word==='among')return [first,card('among-phrase',s.part,'在朋友之中','现在把刚才的词放进短语。先听在朋友之中的表达，再看着跟读。','among friends',['among friends'],['among friends'],{focus:['among']})];
 return [first];
});

export const wordGuides={
 apple:'前面的元音嘴张开、舌位靠前，后面的音节轻一些。',banana:'三个音节，中间音节重读，两端轻一些。',
 and:'这是表示和的连接词。放在句子里可以轻读，不必刻意重读。',or:'这是表示或者的连接词。先听这个词，再放回句子。',
 a:'句子里通常轻读，不要把它当作字母名称来读。',an:'句子里轻读，结尾自然接到后面的词。',
 want:'结尾保留辅音，不要额外加一个元音。',i:'一口气滑动读完，不要拆成两个音节。',
 although:'中间的齿间音，舌尖轻放上下齿之间，声带振动。',though:'开头的齿间音，舌尖轻放上下齿之间，声带振动。',
 despite:'重音在后面的音节，结尾不要多加元音。',difficulty:'这是表示困难的名词，重音在前面的音节。',difficult:'重音在前面的音节，结尾保持简短。',
 however:'中间音节重读，把词读清楚再接后面的句子。',nonetheless:'注意几个音节连起来，先听完整词，再跟着说。',
 against:'后面的音节重读，结尾辅音连起来，不额外加元音。',among:'后面的音节重读，结尾是鼻音，不多加一个音节。',
 except:'后面的音节重读，结尾两个辅音连起来。',friends:'结尾保留表示复数的声音，不额外加一个音节。',proposal:'重音在中间，两端音节轻一些。'
};
export const repairMessages={
 unclear:'这一处没有听清，这次不算读错。请看着提示再说一次。',
 return:'这一处清楚了。现在回到原来的表达，把整句话连起来说。',
 again:'这一处还需要一点帮助。先听局部示范，只说当前这一小段。',
 and:'这次两样都要。表示或者的连接词不适合这里，请换成表示和的连接词。',
 or:'这次任意一种都可以。请用表示或者的连接词，其他部分不用改变。',
 despite:'意思清楚。需要调整的是开头后面的结构。在本课这里，请用表示困难的名词短语。',
 among:'你想表达在朋友这个群体中。表示排除的词不合适，请换成表示在群体之中的词。',
 except:'这里要把我排除在范围外，请用表示除我之外的表达。',
 wording:'这一小段和当前要表达的内容不同。看着标出的部分，先听示范，再说这一小段。'
};

const basic=pilotLessons[0];
basic.steps=basic.steps.filter(s=>!['and-phrase','or-phrase','and-use'].includes(s.id));
basic.steps.sort((a,b)=>['goal','and','and-read','or','or-read','or-use','closing'].indexOf(a.id)-['goal','and','and-read','or','or-read','or-use','closing'].indexOf(b.id));
basic.steps.find(s=>s.id==='goal').body='今天学两个连接词。和表示两样连接起来，或者表示不同选择。在这个例子里，我们要说清两样都要，还是任意一种都可以。';
basic.steps.find(s=>s.id==='goal').display='and：和   /   or：或者';
for(const s of basic.steps){delete s.picture;delete s.scaffold;delete s.supportNote;}
basic.steps.find(s=>s.id==='or-use').body='现在想表达任意一种水果都可以。看着完整提示告诉我，这次不先播放英文答案。';
basic.steps.find(s=>s.id==='closing').body='今天练习了两种表达。需要复习的具体位置会保留。';
const advanced=pilotLessons[1];
const a=advanced.steps.find(s=>s.id==='although-read');a.models=['Although this is difficult, I can try.'];a.body='前半部分承认困难，后半部分说自己可以试试。先听完整句子，再看着说。';a.contrast=['Although this is difficult,','I can try.'];
const d=advanced.steps.find(s=>s.id==='despite-read');d.models=['despite the difficulty','Despite the difficulty, I can try.'];d.body='虽然的后面这里是完整小句，尽管的后面这里用名词短语表示困难。先听短语和完整句，再看着说。';
advanced.steps=advanced.steps.filter(s=>!['although-meaning','despite-structure'].includes(s.id));
const use=advanced.steps.find(s=>s.id==='supported-use');use.body='现在表达事情有困难，自己仍然可以试试。看着完整提示说，也可以使用刚才学过的其他正确说法。';delete use.alternatives;
for(const l of pilotLessons)for(const s of l.steps){delete s.scene;delete s.interaction;delete s.picture;}
