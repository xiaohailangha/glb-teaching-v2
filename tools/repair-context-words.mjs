// Whole lexical words from verified sentence recordings, never isolated IPA.
import fs from 'node:fs';
import crypto from 'node:crypto';
import {cacheDir,readWave,pcmWave,teachingAudio} from '../services/tencent-speech.mjs';
export async function repairContextWords(){
 const dir='scene-preview/assets/avatar/audio';
 const file=dir+'/fruit-prompts.json', manifest=JSON.parse(fs.readFileSync(file));
 for(const [key,source,word,phones] of [
  ['part_i',null,'i',['ay']],
  ['word_a','chunk_red','a',['ah']],
  ['word_an','eat_apple','an',['ah','n']],
  ['word_to','eat_apple','to',['t','uw']],
 ]){
  // Punctuation fixes the single-letter synthesis failure. Keep the complete I.
  const sourceKey=source ? manifest[source].sourceKey : (await teachingAudio('I.',{voice:403008,language:'en'})).key;
  const alignment=JSON.parse(fs.readFileSync(`${cacheDir}/${sourceKey}.alignment.json`));
  const row=alignment.Words.find(w=>w.Word.toLowerCase()===word);
  if(!row || row.MatchTag!==0 || row.PronAccuracy<90 || JSON.stringify(row.PhoneInfos.map(p=>p.Phone))!==JSON.stringify(phones)) throw Error('Unverified source word: '+key);
  const {pcm}=readWave(fs.readFileSync(`${cacheDir}/${sourceKey}.wav`));
  const start=row.MemBeginTime/1000,end=row.MemEndTime/1000;
  const speech=Buffer.from(pcm.subarray(Math.round(start*16000)*2,Math.round(end*16000)*2));
  // Four millisecond boundary fade avoids clicks; no time/pitch manipulation.
  for(let n=0;n<64;n++){speech.writeInt16LE(Math.round(speech.readInt16LE(n*2)*n/64),n*2);const at=speech.length-2-n*2;speech.writeInt16LE(Math.round(speech.readInt16LE(at)*n/64),at);}
  const wav=source ? pcmWave(Buffer.concat([Buffer.alloc(2560),speech,Buffer.alloc(4800)])) : fs.readFileSync(`${cacheDir}/${sourceKey}.wav`);
  const metadata=JSON.parse(fs.readFileSync(`${cacheDir}/${sourceKey}.json`));
  const duration=(wav.length-44)/32000;
  manifest[key]={text:word==='i'?'I':word,voice:403008,bundled:true,duration,
   cues:source ? [{time:0,id:0},...metadata.phones.filter(p=>p.start>=start-.001&&p.end<=end+.001).map(p=>({time:Math.max(0,p.start-start)+.08,id:p.id})),{time:end-start+.08,id:0},{time:duration,id:0}] : metadata.cues,
   sourceKey,contextWord:{source:source??'standalone-I',text:source?manifest[source].text:'I.',start,end,phones},sha256:crypto.createHash('sha256').update(wav).digest('hex')};
  fs.writeFileSync(`${dir}/${key}.wav`,wav);
  console.log(`${key}: contextual whole word ${duration.toFixed(3)}s`);
 }
 fs.writeFileSync(file,JSON.stringify(manifest,null,2)+'\n');
}
if(process.argv[1]?.replaceAll('\\','/').endsWith('/repair-context-words.mjs'))await repairContextWords();
