// Real ASR/SOE against existing reference WAVs, with an isolated temporary DB.
import fs from 'node:fs';import os from 'node:os';import path from 'node:path';
import {LearningStore} from '../services/learning-store.mjs';import {CloudCurriculum} from '../services/cloud-curriculum.mjs';import {TeachingPilot} from '../services/teaching-pilot.mjs';
const directory=fs.mkdtempSync(path.join(os.tmpdir(),'pilot-cloud-smoke-'));
const store=new LearningStore({directory});const pilot=new TeachingPilot(store,new CloudCurriculum(store));
const outcomes=[];let number=0;
try{
 for(const l of pilot.content.lessons){
  const user='isolated-pilot-smoke-'+l.id;
  for(const s of l.steps.filter(s=>s.answers.length||s.practiceAnswers?.length)){
   const answer=s.answers[0]||s.practiceAnswers[0],id=pilot.content.englishIds[answer];if(!id)throw Error('Missing model '+answer);
   const asset=pilot.asset(id,l.id);const result=await pilot.oral(user+'-'+s.id,{revision:pilot.content.revision,course:l.id,step:s.id,attempt:'cloud-smoke-'+(++number),reference:answer,practice:!!s.practiceAnswers,intent:'both',wav:asset.inlineAudio});
   outcomes.push({course:l.id,step:s.id,expected:answer,heard:result.heard,status:result.status,message:result.message,timings:result.timings,scene:result.scene});console.log(JSON.stringify({step:s.id,status:result.status}));
   if(result.status==='passed')await pilot.route('pilot/progress',user+'-'+s.id,{revision:pilot.content.revision,course:l.id,step:s.id,outcome:'passed',attempt:result.attempt},new URL('https://example.test'));
  }
 }
 fs.writeFileSync('data/teaching-pilot/cloud-smoke.json',JSON.stringify({referencePlaybackNotHumanSpeech:true,total:outcomes.length,passed:outcomes.filter(x=>x.status==='passed').length,outcomes},null,2));
 if(outcomes.some(x=>x.status!=='passed'))process.exitCode=1;
}finally{store.close();fs.rmSync(directory,{recursive:true,force:true});}
