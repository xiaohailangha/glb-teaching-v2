import fs from 'node:fs';import {cacheDir} from '../services/tencent-speech.mjs';
const file='scene-preview/assets/avatar/audio/fruit-prompts.json', manifest=JSON.parse(fs.readFileSync(file));
let count=0;
for(const m of Object.values(manifest)){
 if(!/^[A-Za-z]/.test(m.text))continue;
 const source=JSON.parse(fs.readFileSync(`${cacheDir}/${m.sourceKey}.json`));
 const aligned=JSON.parse(fs.readFileSync(`${cacheDir}/${m.sourceKey}.alignment.json`));
 let offset= .05-Math.max(0,source.phones[0].start-.03);
 if(m.contextWord)offset=m.contextWord.source==='standalone-I'?0:.08-m.contextWord.start;
 const expected=m.text.toLowerCase().match(/[a-z]+(?:'[a-z]+)?/g)||[];
 const rows=aligned.Words.filter(w=>!m.contextWord||m.contextWord.source==='standalone-I'||w.MemBeginTime>=m.contextWord.start*1000-.1&&w.MemEndTime<=m.contextWord.end*1000+.1);
 if(rows.length!==expected.length||rows.some((w,i)=>w.Word.toLowerCase()!==expected[i]))throw Error('Alignment mismatch '+m.text);
 m.wordTimings=rows.map(w=>({word:w.Word.toLowerCase(),start:Math.max(0,w.MemBeginTime/1000+offset),end:Math.min(m.duration,w.MemEndTime/1000+offset)}));count++;
}
fs.writeFileSync(file,JSON.stringify(manifest,null,2)+'\n');console.log('Aligned teaching clips:',count);
