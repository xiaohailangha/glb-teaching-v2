import fs from 'node:fs/promises';import crypto from 'node:crypto';import assert from 'node:assert/strict';
const root='data/teaching-pilot',c=JSON.parse(await fs.readFile(root+'/current.json'));
const normalize=s=>s.replace(/[^\p{Script=Han}]/gu,'').replace(/作/g,'做').replace(/原音|原因/g,'元音').replace(/上颚/g,'上腭').replace(/口型/g,'口形').replace(/在学/g,'再学').replace(/[他她]/g,'它').replace(/一会儿/g,'一会').replace(/震动/g,'振动').replace(/齿尖音/g,'齿间音').replace(/题意/g,'提议').replace(/恋/g,'练');
const results=[];
for(const a of Object.values(c.assets)){
 const base=a.source==='formal'?'data/curriculum/cloud-runtime/releases/'+c.release:root,wav=await fs.readFile(base+'/'+a.file);
 assert.equal(crypto.createHash('sha256').update(wav).digest('hex'),a.sha256);assert.equal(a.voice,403008);assert.ok(a.cues.length>1);
 let previous=-1;for(const cue of a.cues){assert.ok(cue.time>=previous);previous=cue.time;}assert.equal(a.cues.at(-1).id,0);
 assert.ok(a.speechEndMs>0&&a.speechEndMs<=(wav.length-44)/32+1);
 if(a.language==='zh'){
  const e=JSON.parse(await fs.readFile(root+'/evidence/'+a.id+'.json'));
  if(e.asset){assert.equal(e.asset.sha256,a.sha256);assert.ok(e.assessment.PronAccuracy>=90&&e.assessment.PronCompletion>=.98);assert.equal(normalize(e.recognition.text),normalize(a.text));}
  else {assert.equal(e.sha256,a.sha256);assert.ok(e.quality.accuracy>=90&&e.quality.completion>=.98);const r=JSON.parse(await fs.readFile(root+'/evidence/'+a.sha256+'.asr.json'));assert.equal(r.sha256,a.sha256);assert.equal(normalize(r.expected),normalize(a.text));assert.equal(normalize(r.heard),normalize(a.text));}
  assert.equal(a.cueSource,'soe-mandarin-phone-timing');
 }
 results.push({id:a.id,language:a.language,sha256:a.sha256,checked:true});
}
const report={revision:c.revision,at:new Date().toISOString(),assets:results.length,chinese:results.filter(a=>a.language==='zh').length,english:results.filter(a=>a.language==='en').length,passed:results.length,verification:'existing independent ASR/SOE receipts, real phone cues and WAV hashes; no new paid requests',results};
await fs.writeFile(root+'/audio-check.json',JSON.stringify(report,null,2));console.log(JSON.stringify({...report,results:undefined}));
