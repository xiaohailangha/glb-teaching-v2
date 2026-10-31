import fs from 'node:fs';
import path from 'node:path';
import {teachingAudio,cacheDir} from '../services/tencent-speech.mjs';
const dir='scene-preview/assets/avatar', prompts={};
const addClip=(id,text)=>(prompts[id]=text,id);
const opt=[{id:'next',label:'继续'},{id:'help',label:'再听示范'}];
function course(id,title){return {id,title,stages:[]};}
function practice(c,id,word,text,meaning,clip,picture='',segments=[]){
 c.stages.push({id:id+'_model',phase:'demonstrate',chapter:c.title,word,display:text,text:meaning,clip,picture});
 c.stages.push({id,phase:'listen',chapter:c.title,word,display:text,text:meaning,practiceClip:clip,speechText:text,picture,segments,options:opt});
}
function intro(c,key,text){c.stages.push({id:'intro',phase:'introduce',chapter:c.title,word:'apple',display:c.title,text,clip:addClip(key,text)});}
function finish(c){c.stages.push({id:'summary',phase:'finish',chapter:'本节小结',word:'apple',display:'本节学习记录',text:'本节课我们就学到这里。',options:[]});}
const drinks=course('adult-drinks-v1','02 · 水和饮料');
intro(drinks,'drinks_intro','这节课认识四种饮品。先读单词，再用学过的表达，说说你想要什么。');
const names={water:'水',milk:'牛奶',tea:'茶',coffee:'咖啡'};
for(const [w,zh] of Object.entries(names)) practice(drinks,'word_'+w,w,w,zh,addClip('unit_'+w,w),w);
practice(drinks,'some','water','some','一些；这里不说具体数量。',addClip('unit_some','some'));
for(const [w,zh] of Object.entries(names)){
 const phrase='some '+w;
 practice(drinks,'some_'+w,w,phrase,'一些'+zh+'。这里不按一个、两个来数。',addClip('unit_some_'+w,phrase),w);
 practice(drinks,'want_'+w,w,'I want '+phrase+'.','我想要一些'+zh+'。',addClip('unit_want_'+w,'I want '+phrase+'.'),w,[{label:'I want',clip:'chunk_want'},{label:phrase,clip:'unit_some_'+w}]);
}
finish(drinks);
const polite=course('adult-polite-v1','03 · 礼貌请求');
intro(polite,'polite_intro','这节课练习礼貌请求。先听，再跟着说。');
practice(polite,'please','apple','please','请；让请求更礼貌。',addClip('unit_please','please'));
for(const [w,p,zh] of [['apple','an apple','一个苹果'],['banana','a banana','一根香蕉'],['water','some water','一些水']]){
 const phraseClip=w==='water'?'unit_some_water':'phrase_'+w;
 practice(polite,'request_'+w,w,p[0].toUpperCase()+p.slice(1)+', please.','请给我'+zh+'。',addClip('unit_request_'+w,p[0].toUpperCase()+p.slice(1)+', please.'),w,[{label:p,clip:phraseClip},{label:'please',clip:'unit_please'}]);
}
practice(polite,'thank','apple','thank','感谢；接下来和 you 连起来说。',addClip('unit_thank','thank'));
practice(polite,'you','apple','you','你；和 thank 连起来就是谢谢你。',addClip('unit_you','you'));
practice(polite,'thanks','apple','Thank you.','谢谢你。收到东西后可以这样回应。',addClip('unit_thank_you','Thank you.'));
practice(polite,'complete','water','I want some water, please.','我想要一些水，谢谢。完整说出需求，也可以用前面的简短请求。',addClip('unit_polite_water','I want some water, please.'),'water',[{label:'I want',clip:'chunk_want'},{label:'some water',clip:'unit_some_water'},{label:'please',clip:'unit_please'}]);
finish(polite);
const review=course('adult-shop-v1','04 · 水果饮品店');
intro(review,'shop_intro','这节课一起复习。听听示范，再说说你想要什么。');
for(const [id,w,text,zh,clip] of [
 ['apple','apple','An apple, please.','来到水果摊：请给我一个苹果。','unit_request_apple'],
 ['thanks_one','apple','Thank you.','收到苹果，向对方说谢谢。','unit_thank_you'],
 ['milk','milk','I want some milk.','看看饮品柜：我想要一些牛奶。','unit_want_milk'],
 ['water','water','Some water, please.','再练一种简短请求：请给我一些水。','unit_request_water'],
 ['thanks_two','water','Thank you.','拿到饮品，再自然地说声谢谢。','unit_thank_you'],
]) practice(review,id,w,text,zh,clip,id.startsWith('thanks')?'':w);
finish(review);
for(const [file,c] of [['adult-drinks',drinks],['adult-polite',polite],['adult-shop',review]]) fs.writeFileSync(`${dir}/courses/${file}.json`,JSON.stringify(c,null,2)+'\n');
if(process.argv.includes('--course-only')) process.exit(0);
const file=`${dir}/audio/unit-one-prompts.json`, manifest=fs.existsSync(file)?JSON.parse(fs.readFileSync(file)):{};
for(const [key,text] of Object.entries(prompts)){
 if(manifest[key]?.text===text&&fs.existsSync(`${dir}/audio/${key}.wav`))continue;
 const source=await teachingAudio(text,{voice:403008,language:/[\u3400-\u9fff]/.test(text)?'zh':'en'});
 fs.copyFileSync(path.join(cacheDir,source.key+'.wav'),`${dir}/audio/${key}.wav`);
 const alignment=JSON.parse(fs.readFileSync(path.join(cacheDir,source.key+'.alignment.json')));
 const expected=text.toLowerCase().match(/[a-z]+(?:'[a-z]+)?/g)||[];
 const words=alignment.Words||[];
 if(expected.length && (words.length!==expected.length||words.some((w,i)=>w.Word.toLowerCase()!==expected[i])))throw Error('Word alignment mismatch: '+key);
 manifest[key]={text,voice:403008,bundled:true,duration:source.duration,cues:source.cues,sourceKey:source.key,wordTimings:expected.length?words.map(w=>({word:w.Word.toLowerCase(),start:w.MemBeginTime/1000,end:w.MemEndTime/1000})):[]};
 fs.writeFileSync(file,JSON.stringify(manifest,null,2)+'\n');console.log('Prepared '+key);
}
