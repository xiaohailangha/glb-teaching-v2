import fs from 'node:fs/promises';
import crypto from 'node:crypto';
import {recognize} from '../services/tencent-speech.mjs';
const root='data/teaching-pilot',content=JSON.parse(await fs.readFile(root+'/current.json'));
// Spoken homophones are equivalent; keep the original transcript as evidence.
const normalize=s=>s.replace(/[^\p{Script=Han}]/gu,'').replace(/作/g,'做').replace(/原音|原因/g,'元音').replace(/上颚/g,'上腭').replace(/口型/g,'口形').replace(/在学/g,'再学');
const assets=Object.values(content.assets).filter(a=>a.source==='pilot'&&a.language==='zh');
let cursor=0,done=0;const results=[];
async function worker(){while(cursor<assets.length){const a=assets[cursor++],file=root+'/evidence/'+a.sha256+'.asr.json';let r;
 try{r=JSON.parse(await fs.readFile(file));if(r.sha256!==a.sha256)throw Error();}catch{
  const wav=await fs.readFile(root+'/'+a.file);if(crypto.createHash('sha256').update(wav).digest('hex')!==a.sha256)throw Error('Audio hash');
  const heard=await recognize(wav,{engine:'16k_zh_en_2.0'});r={sha256:a.sha256,expected:a.text,heard:heard.text,accepted:normalize(a.text)===normalize(heard.text)};await fs.writeFile(file,JSON.stringify(r,null,2));
 }
 r.accepted=normalize(r.expected)===normalize(r.heard);results.push(r);done++;console.log(done+'/'+assets.length+(r.accepted?' verified':' MISMATCH '+a.id));
}}
await Promise.all([worker(),worker()]);await fs.writeFile(root+'/audio-check.json',JSON.stringify({total:results.length,passed:results.filter(r=>r.accepted).length,results},null,2));if(results.some(r=>!r.accepted))process.exitCode=1;
