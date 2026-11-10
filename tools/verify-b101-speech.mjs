import fs from 'node:fs';import path from 'node:path';import os from 'node:os';
import {LearningStore} from '../services/learning-store.mjs';
import {CurriculumStore,runtimeChecks,sample,curriculumVersion} from '../services/curriculum.mjs';
import {CurriculumEvidence} from '../services/curriculum-evidence.mjs';
const root=fs.mkdtempSync(path.join(os.tmpdir(),'snow-real-speech-')),store=new LearningStore({directory:root}),c=new CurriculumStore(store),e=new CurriculumEvidence(c,{checks:runtimeChecks,words:sample.words,steps:sample.steps,version:curriculumVersion});c.evidence=e;c.selectLevel('synthetic-verification',{level:1,revision:0});
const models={C01:'hello',C02:'bye',C04:'good',C06:'im-li',C08:'my-name-li',C10:'from-china',U01:'hi',U02:'my-name-lin',U03:'from-japan',U04:'bye'};
const report={scope:'real Tencent ASR and assessment, synthetic model recordings; not a human learner study',rows:[]};
try{for(const [id,key] of Object.entries(models)){
 const check=runtimeChecks.find(c=>c.id===id),ch=e.challenge('synthetic-verification',{check:id,course:check.course,version:curriculumVersion});
 for(const audio of check.audio)e.heard('synthetic-verification',{challenge:ch.id,audio});
 const r=await e.answer('synthetic-verification',{challenge:ch.id,mode:'oral',wav:fs.readFileSync(`work/b101-audio/B101-${key}.wav`).toString('base64')});
 report.rows.push({id,model:key,verified:r.verified,heard:r.heard,score:r.score,message:r.message});console.log(JSON.stringify(report.rows.at(-1)));fs.writeFileSync('work/b101-audio/live-speech-verification.json',JSON.stringify(report,null,2));
}
}finally{store.close();fs.rmSync(root,{recursive:true,force:true});}
if(report.rows.some(r=>!r.verified))process.exitCode=1;
