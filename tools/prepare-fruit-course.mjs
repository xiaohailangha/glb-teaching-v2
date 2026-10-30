import fs from 'node:fs';
import path from 'node:path';
import {teachingAudio,cacheDir,readWave,pcmWave} from '../services/tencent-speech.mjs';
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
};
const stages=[];
const option=(id,label)=>({id,label});
function add(id,phase,chapter,word,text,extra={}) {stages.push({id,phase,chapter,word,text,...extra});}
add('fruit_intro','introduce','认识水果','apple','这节课：认出两个水果，听懂它们，试着说出名字。',{clip:'fruit_intro',display:'APPLE · BANANA'});
for(const word of ['apple','banana']) {
 const meaning=word==='apple'?'苹果':'香蕉';
 add(`${word}_meaning`,'meaning','认识水果',word,meaning,{clip:`fruit_${word}`,picture:word,display:meaning});
 add(`${word}_model`,'demonstrate','认识水果',word,'先听完整单词。',{clip:word,picture:word,display:word});
 add(`${word}_practice`,'listen','试着发音',word,word==='apple'?'先读完整单词。需要时可单独听 /æ/。':'中间的 /næ/ 读重一些，开头和结尾轻一些。',
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
for(const word of ['banana','apple']) add(`recall_${word}`,'recall','看图回忆',word,'看图试着说出英文。可以点“说出答案”录音，也可以自己轻声练习。',
 {picture:word,hide:true,options:[option('attempt','我尝试过了'),option('reveal','想不起来，听提示')]});
add('phrase_intro','explain','连起来说','apple','从单词走到“一个苹果 / 一根香蕉”。',{clip:'fruit_phrase',display:'一个苹果 · 一根香蕉'});
for(const word of ['apple','banana']) add(`phrase_${word}_model`,'demonstrate','连起来说',word,word==='apple'?'一个苹果':'一根香蕉',{picture:word,display:word==='apple'?'an apple':'a banana',clip:`phrase_${word}`});
add('article_tip','explain','连起来说','apple','an apple · a banana。先把这两组说法记在一起。',{clip:'fruit_article',display:'an apple / a banana'});
choice('phrase_select','banana','连起来说',true,true);
add('review_intro','transfer','隔一会再认','apple','换个顺序，不看英文，再认一次。',{clip:'fruit_review',hide:true});
choice('review_banana','banana','隔一会再认');choice('review_apple','apple','隔一会再认',true);
add('close','encourage','本节小结','apple','完成了一次练习，不代表已经永久记住。',{clip:'fruit_finish',display:'完成本节练习'});
add('summary','finish','本节小结','apple','下次可以再练一轮，检查是否还记得。',{display:'今天的学习记录',options:[]});
fs.mkdirSync('scene-preview/assets/avatar/courses',{recursive:true});
fs.writeFileSync('scene-preview/assets/avatar/courses/adult-fruit.json',JSON.stringify({id:'adult-fruit-v1',title:'成人入门 · 认识水果',stages},null,2)+'\n');
const result={};
for(const [key,text] of Object.entries(prompts)) {
 const source=await teachingAudio(text,{voice:403008,language:key.startsWith('phrase_')?'en':'zh'});
 const {pcm}=readWave(fs.readFileSync(path.join(cacheDir,source.key+'.wav')));
 const start=Math.max(0,source.phones[0].start-.03),end=Math.min(source.duration,source.phones.at(-1).end+.08);
 const clip=pcmWave(Buffer.concat([Buffer.alloc(1600),pcm.subarray(Math.floor(start*16000)*2,Math.ceil(end*16000)*2),Buffer.alloc(2400)]));
 const cues=[{time:0,id:0},...source.cues.filter(c=>c.time>=start&&c.time<=end).map(c=>({...c,time:c.time-start+.05})),{time:end-start+.05,id:0}];
 fs.writeFileSync(path.join(audioDir,key+'.wav'),clip);
 result[key]={text,voice:403008,bundled:true,duration:(clip.length-44)/32000,cues,sourceKey:source.key};
 fs.writeFileSync(path.join(audioDir,'fruit-prompts.json'),JSON.stringify(result,null,2)+'\n');
 console.log(`${key}: ${result[key].duration.toFixed(2)}s`);
}
