import fs from 'node:fs';
import path from 'node:path';
import {projectRoot,cacheDir,configured,versions,teachingAudio,recognize,assess} from '../services/tencent-speech.mjs';
const output=path.join(projectRoot,'docs/tencent-integration');fs.mkdirSync(output,{recursive:true});
const report={testedAt:new Date().toISOString(),versions,tests:[],syntheticAudioOnly:true};
if(!configured()){console.log('腾讯凭据尚未配置；未调用付费 API。');process.exitCode=2;}
else{
  const cases=[['apple','en'],['I like apples.','en'],['我们一起学习这个单词。','zh']];
  for(const [text,language]of cases){
    try{const result=await teachingAudio(text,{language});report.tests.push({type:'tts-and-lips',text,voice:result.voice,duration:result.duration,phoneCount:result.phones.length,missing:result.missing,subtitles:result.subtitles,source:result.source,cached:result.cached,key:result.key,passed:true});console.log(`${text}: ${result.phones.length} 个音素，${result.duration.toFixed(2)} 秒`);}
    catch(e){report.tests.push({type:'tts-and-lips',text,passed:false,error:e.message});console.log(`${text}: ${e.message}`);}
  }
  try{
    const generated=await teachingAudio('I like apples.');
    const wav=fs.readFileSync(path.join(cacheDir,`${generated.key}.wav`));
    const asr=await recognize(wav);report.tests.push({type:'asr',...asr,passed:/apple/i.test(asr.text)});
    const score=await assess(wav,{text:'I like apples.'});report.tests.push({type:'assessment',reference:'I like apples.',result:score,passed:Array.isArray(score.Words)&&score.Words.length>0});
  }catch(e){report.tests.push({type:'recognition-assessment',passed:false,error:e.message});}
  fs.writeFileSync(path.join(output,'latest-report.json'),JSON.stringify(report,null,2));
  console.log(JSON.stringify(report.tests.map(({result,...t})=>({...t,...(result?{score:result.PronAccuracy,words:result.Words?.length}:{})})),null,2));if(report.tests.some(t=>!t.passed))process.exitCode=1;
}
