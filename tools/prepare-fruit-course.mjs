import fs from 'node:fs';
import path from 'node:path';
import {teachingAudio,cacheDir,readWave,pcmWave} from '../services/tencent-speech.mjs';
import {repairContextWords} from './repair-context-words.mjs';
const audioDir='scene-preview/assets/avatar/audio';
const prompts={
 fruit_intro:'今天认识苹果和香蕉。先听，再选择，最后试着自己说。随时可以暂停。',
 fruit_apple:'这是苹果。听听它的英文。',
 fruit_banana:'这是香蕉。它的英文和苹果不一样，仔细听。',
 fruit_choose:'接下来只听声音，选出对应的水果。',
 fruit_correct:'选对了。',
 fruit_recall:'现在看图片，试着想起英文。想不起来可以听提示。',
 fruit_phrase:'说一个苹果和一根香蕉时，前面还要加一个短词。先听这两种说法。',
 fruit_article:'前面的短词不同。跟着示范，连起来说。',
 fruit_review:'换个顺序，再听一次。看看现在能不能认出来。',
 fruit_finish:'这一节完成了。下次再试试，看看还能不能记住。',
 phrase_apple:'an apple',phrase_banana:'a banana',
 word_a:'a',word_an:'an',word_to:'to',
 want_intro:'现在说出你想要什么。先听，再分段练习。',
 eat_intro:'想要吃，和想要一个东西，有一点不同。听听这句话。',
 scene_intro:'现在试着表达自己的选择。先选水果，再开口说。',
 red_intro:'红色，英文是 red。把颜色放在苹果前面。',
 part_i:'I',part_want:'want',part_eat:'eat',part_red:'red',
 chunk_want:'I want.',chunk_eat:'to eat.',chunk_red:'a red apple',
 want_apple:'I want an apple.',want_banana:'I want a banana.',
 eat_apple:'I want to eat an apple.',eat_banana:'I want to eat a banana.',
 eat_red:'I want to eat a red apple.',
};
const stages=[];
const option=(id,label)=>({id,label});
function add(id,phase,chapter,word,text,extra={}) {stages.push({id,phase,chapter,word,text,...extra});}
add('fruit_intro','introduce','认识水果','apple','从苹果、一个苹果，走到“我想要 / 我想吃一个苹果”。红苹果是可选扩展。',{clip:'fruit_intro',display:'从单词到表达'});
for(const word of ['apple','banana']) {
 const meaning=word==='apple'?'苹果':'香蕉';
 add(`${word}_meaning`,'meaning','认识水果',word,meaning,{clip:`fruit_${word}`,picture:word,display:meaning});
 add(`${word}_model`,'demonstrate','认识水果',word,'先听完整单词。',{clip:word,picture:word,display:word});
 add(`${word}_practice`,'listen','试着发音',word,word==='apple'?'先读完整单词，留意开头的 /æ/。轻触人物可重听。':'中间的 /næ/ 读重一些，开头和结尾轻一些。',
  {picture:word,display:word,options:[option('next','继续'),option('help','再听整词')]});
}
add('choose_intro','explain','听音辨认','apple','只听声音，选图片。',{clip:'fruit_choose',hide:true});
function choice(id,word,chapter,reverse=false,phrase=false) {
 const clip=phrase?`phrase_${word}`:word;
 add(`${id}_cue`,'choice',chapter,word,'听声音…',{clip,hide:true});
 const answers=phrase?[option('phrase_apple','an apple'),option('phrase_banana','a banana')]:[option('apple','苹果'),option('banana','香蕉')];
 add(id,'choice',chapter,word,phrase?'图里的水果，应该怎样说？':'刚才听到的是哪一个？',{
  picture:phrase?word:'',answer:clip,hide:true,options:[...(reverse?answers.reverse():answers),option('help','再听一次')]});
}
choice('hear_apple','apple','听音辨认');choice('hear_banana','banana','听音辨认',true);
add('recall_intro','invite','看图回忆','apple','先想一想，再听提示。',{clip:'fruit_recall',hide:true});
for(const word of ['banana','apple']) add(`recall_${word}`,'recall','看图回忆',word,'看图直接说出英文。想再听一次，轻触人物。',
 {picture:word,hide:true,options:[option('attempt','我尝试过了'),option('reveal','想不起来，听提示')]});
add('phrase_intro','explain','连起来说','apple','从单词走到“一个苹果 / 一根香蕉”。',{clip:'fruit_phrase',display:'一个苹果 · 一根香蕉'});
for(const word of ['apple','banana']) practice(`phrase_${word}_practice`,'连起来说',word,word==='apple'?'an apple':'a banana',word==='apple'?'一个苹果':'一根香蕉',`phrase_${word}`);
add('article_tip','explain','连起来说','apple','an apple · a banana。先把这两组说法记在一起。',{clip:'fruit_article',display:'an apple / a banana'});
choice('phrase_select','banana','连起来说',true,true);
function practice(id, chapter, word, display, text, clip, extra={}) {
 const picture=['learn_i','learn_want','learn_eat','chunk_want','chunk_eat'].includes(id)?'':word;
 add(id+'_model','demonstrate',chapter,word,text,{display,picture,clip});
 add(id,'listen',chapter,word,text,{display,picture,practiceClip:clip,speechText:display,
  options:[option('next','继续'),option('help','再听示范')],...extra});
}
add('want_intro','explain','表达想要','apple','I = 我；want = 想要。先理解，再把它们连起来。',{clip:'want_intro',display:'我想要…'});
practice('learn_i','表达想要','apple','I','我。这里开始学习组成句子的词。','part_i');
practice('learn_want','表达想要','apple','want','想要。','part_want');
practice('chunk_want','表达想要','apple','I want','我想要… 后面接想要的东西。','chunk_want');
for (const word of ['apple','banana']) {
 const phrase=word==='apple'?'an apple':'a banana';
 practice(`want_${word}`,'表达想要',word,`I want ${phrase}.`,`我想要${word==='apple'?'一个苹果':'一根香蕉'}。听完直接说。需要时轻触人物重听。`,`want_${word}`,{segments:[{clip:'chunk_want',label:'I want'},{clip:`phrase_${word}`,label:phrase}]});
}
add('eat_intro','explain','表达想吃','apple','eat = 吃；want to eat = 想吃。to 在这里帮助连接 want 和 eat，先把组合记在一起。',{clip:'eat_intro',display:'从“想要”到“想吃”'});
practice('learn_eat','表达想吃','apple','eat','吃。','part_eat');
practice('chunk_eat','表达想吃','apple','to eat','和 I want 连起来：I want to eat… 我想吃…','chunk_eat');
for (const word of ['apple','banana']) {
 const phrase=word==='apple'?'an apple':'a banana';
 practice(`eat_${word}`,'表达想吃',word,`I want to eat ${phrase}.`,`我想吃${word==='apple'?'一个苹果':'一根香蕉'}。分段练过后，再试着完整说。`,`eat_${word}`,{segments:[{clip:'chunk_want',label:'I want'},{clip:'chunk_eat',label:'to eat'},{clip:`phrase_${word}`,label:phrase}]});
}
add('scene_intro','invite','自己表达','apple','选你想吃的水果，再试着说出完整需求。',{clip:'scene_intro',display:'轮到你来选择'});
add('scene_pick','choice','自己表达','apple','你想吃哪一种？这是你的选择，没有标准答案。',{hide:true,options:[option('choose_apple','苹果'),option('choose_banana','香蕉')]});
for (const word of ['apple','banana']) add(`scene_${word}`,'recall','自己表达',word,'没有英文提示，试着说“我想吃…”；录音不是必选，也可以自己轻声说。',{picture:word,hide:true,practiceClip:`eat_${word}`,speechText:`I want to eat ${word==='apple'?'an apple':'a banana'}.`,options:[option('attempt','我尝试过了'),option('help','听完整示范')]});
add('extension_gate','listen','可选扩展','apple','核心表达已练完。可以学习“红苹果”，也可以结束本课。',{display:'要加一点颜色吗？',options:[option('next','学习红苹果'),option('skip','结束本课')]});
add('red_intro','explain','红苹果扩展','apple','red = 红色。a red apple = 一个红苹果。这里用 a，因为它紧接 red 的辅音开头。',{clip:'red_intro',display:'red → a red apple'});
practice('learn_red','红苹果扩展','apple','red','红色。','part_red');
practice('red_phrase','红苹果扩展','apple','a red apple','一个红苹果。','chunk_red');
practice('red_sentence','红苹果扩展','apple','I want to eat a red apple.','我想吃一个红苹果。先分段，再连起来说。','eat_red',{segments:[{clip:'chunk_want',label:'I want'},{clip:'chunk_eat',label:'to eat'},{clip:'chunk_red',label:'a red apple'}]});
add('summary','finish','本节小结','apple','本节课我们就学到这里。',{display:'今天的学习记录',options:[]});
fs.mkdirSync('scene-preview/assets/avatar/courses',{recursive:true});
fs.writeFileSync('scene-preview/assets/avatar/courses/adult-fruit.json',JSON.stringify({id:'adult-fruit-v2',title:'成人入门 · 从水果到表达',stages},null,2)+'\n');
if (process.argv.includes('--course-only')) process.exit(0);
const result={};
for(const [key,text] of Object.entries(prompts)) {
 const source=await teachingAudio(text,{voice:403008,language:/^[A-Za-z]/.test(text)?'en':'zh'});
 const {pcm}=readWave(fs.readFileSync(path.join(cacheDir,source.key+'.wav')));
 const start=Math.max(0,source.phones[0].start-.03),end=Math.min(source.duration,source.phones.at(-1).end+.08);
 const clip=pcmWave(Buffer.concat([Buffer.alloc(1600),pcm.subarray(Math.floor(start*16000)*2,Math.ceil(end*16000)*2),Buffer.alloc(2400)]));
 const cues=[{time:0,id:0},...source.cues.filter(c=>c.time>=start&&c.time<=end).map(c=>({...c,time:c.time-start+.05})),{time:end-start+.05,id:0}];
 fs.writeFileSync(path.join(audioDir,key+'.wav'),clip);
 result[key]={text,voice:403008,bundled:true,duration:(clip.length-44)/32000,cues,sourceKey:source.key};
 fs.writeFileSync(path.join(audioDir,'fruit-prompts.json'),JSON.stringify(result,null,2)+'\n');
 console.log(`${key}: ${result[key].duration.toFixed(2)}s`);
}
await repairContextWords();
await import('./prepare-word-highlights.mjs');
