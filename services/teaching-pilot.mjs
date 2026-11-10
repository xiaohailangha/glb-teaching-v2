import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {projectRoot} from './storage-paths.mjs';
import {recognize,assess,validateAudio} from './tencent-speech.mjs';
import {PhoneticReferences} from './phonetic-reference.mjs';
import {recognizeRecording} from './recording-recognition.mjs';
import {sceneForSpeech,sceneAction} from './teaching-pilot-scenes.mjs';
const fail=(status,message)=>{throw Object.assign(Error(message),{status});};
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
export const pilotTokens=s=>(String(s).toLowerCase().match(/[a-z]+(?:'[a-z]+)?/g)||[]);
const norm=s=>pilotTokens(s).join(' ');
const phones={ae:'æ',dh:'ð',th:'θ',iy:'iː',ih:'ɪ',ow:'oʊ',n:'n',l:'l',z:'z',t:'t',p:'p',b:'b',d:'d',r:'ɹ',s:'s',ah:'ə',ax:'ə'};
export const soundTips={'æ':'嘴张开、舌位靠前，先听这个元音。','ð':'舌尖轻放上下齿之间，声带振动。','θ':'舌尖轻放上下齿之间，轻轻送气。','iː':'舌位靠前，保持这个元音，不另加音节。','ɪ':'这个元音短一些，嘴不要绷得太紧。','oʊ':'口形自然滑动，一口气读完。','n':'舌尖抵住上齿后方，让气流从鼻腔通过。','l':'舌尖轻触上齿后方，气流从舌头两侧通过。','z':'声带振动，结尾不要额外加元音。','t':'舌尖接触上齿后方，再放开，不多加一个音节。','p':'双唇先合拢，再轻轻放开。','b':'双唇先合拢，再放开，声带振动。','d':'舌尖接触上齿后方，再放开，声带振动。','ɹ':'舌尖不要碰上腭，先听这个辅音。','s':'让气流从齿间窄缝通过，不多加元音。','ə':'放松口形，轻轻读这个元音。'};
function differences(a,b){const n=a.length,m=b.length,d=Array.from({length:n+1},()=>Array(m+1).fill(0));for(let i=0;i<=n;i++)d[i][0]=i;for(let j=0;j<=m;j++)d[0][j]=j;for(let i=1;i<=n;i++)for(let j=1;j<=m;j++)d[i][j]=Math.min(d[i-1][j]+1,d[i][j-1]+1,d[i-1][j-1]+(a[i-1]===b[j-1]?0:1));return d[n][m];}
export function pilotDecision(step,heard,result,{target=null,available=()=>true}={}){
 const answers=target?[target]:step.answers,spoken=pilotTokens(heard);
 const expected=[...answers].sort((a,b)=>differences(pilotTokens(a),spoken)-differences(pilotTokens(b),spoken))[0];
 const tokens=pilotTokens(expected),matched=answers.some(a=>norm(a)===norm(heard));
 if(!spoken.length)return {status:'unclear',message:'没有听到清楚的回答，这次不算读错。请看着提示再说一次。',messageKey:'unclear',target:expected};
 if(!matched){
  let key='wording',local='',index=tokens.findIndex((w,i)=>spoken[i]!==w);
  if(!target&&tokens.includes('and')&&spoken.includes('or')){key='and';index=tokens.indexOf('and');local='an apple and a banana';}
  else if(!target&&tokens.includes('or')&&spoken.includes('and')){key='or';index=tokens.indexOf('or');local='an apple or a banana';}
  else if(!target&&tokens[0]==='despite'&&/^despite (this|it) is\b/.test(norm(heard))){key='despite';local='despite the difficulty';index=0;}
  else if(!target&&tokens[0]==='among'&&spoken.includes('except')){key='among';local=expected;index=0;}
  else if(!target&&tokens[0]==='except'&&spoken.includes('among')){key='except';local=expected;index=0;}
  if(differences(tokens,spoken)>Math.max(3,tokens.length*.65)&&key==='wording')return {status:'unclear',message:'这次听到的内容与当前任务差别较大，请确认麦克风后，看着提示再说。',messageKey:'unclear',target:expected};
  index=Math.max(0,index);if(!local)local=available(tokens[index])?tokens[index]:expected;
  return {status:'repair',type:key==='despite'?'structure':key==='wording'?'wording':'meaning',messageKey:key,target:local,original:expected,index,word:tokens[index],message:key==='wording'?`我听到的是“${heard}”。请核对标出的 ${tokens[index]}，先练这一处。`:null};
 }
 const rows=result?.Words;
 if(!Array.isArray(rows)||rows.length!==tokens.length||rows.some((w,i)=>norm(w.Word)!==tokens[i]||w.MatchTag!==0||!Number.isFinite(w.PronAccuracy))||result.PronCompletion<.98)return {status:'unclear',message:'意思已经听到了，但这一轮声音评测还不完整。这次不算读错，请再说一次。',messageKey:'unclear',target:expected};
 const feedback=rows.map((w,i)=>({word:tokens[i],index:i,score:w.PronAccuracy,status:w.PronAccuracy<(tokens.length>1&&['a','an','and','or','the','to','of'].includes(tokens[i])?50:60)?'retry':'good'}));
 const weak=feedback.filter(w=>w.status==='retry').sort((a,b)=>a.score-b.score)[0];
 if(!weak){const mean=rows.reduce((s,w)=>s+w.PronAccuracy,0)/rows.length;if(mean>=75)return {status:'passed',target:expected,wordFeedback:feedback};return {status:'unclear',message:'意思正确，这次整体评测还不稳定。保留提示，再试一次。',messageKey:'unclear',target:expected};}
 const low=(rows[weak.index].PhoneInfos||[]).filter(p=>p.MatchTag===0&&Number.isFinite(p.PronAccuracy)&&p.PronAccuracy>=0&&p.PronAccuracy<60).sort((a,b)=>a.PronAccuracy-b.PronAccuracy)[0];
 const phone=low?phones[String(low.Phone).replace(/[0-9]/g,'').toLowerCase()]:null;
 const stress=(rows[weak.index].PhoneInfos||[]).some(p=>p.Stress===true&&p.DetectedStress===false);
 const phrase=tokens.slice(weak.index,weak.index+2).join(' ');
 return {status:'repair',type:'pronunciation',target:available(weak.word)?weak.word:available(phrase)?phrase:expected,original:expected,index:weak.index,word:weak.word,phone,stress,message:`第 ${weak.index+1} 个词 ${weak.word} 需要局部练习。${phone?`当前重点是 /${phone}/。`:stress?'注意这个词的重音。':'先听清这个词，再跟着说。'}`,wordFeedback:feedback};
}

export class TeachingPilot {
 fallbackRecognizer=recognize;
 constructor(store,curriculum,{directory=path.join(projectRoot,'data/teaching-pilot'),recognizer=recognizeRecording,assessor=assess}={}){Object.assign(this,{store,db:store.db,curriculum,directory,recognizer,assessor});this.inFlight=new Set();this.limits=new Map();this.db.exec(`CREATE TABLE IF NOT EXISTS teaching_pilot_visits(user_id TEXT,revision TEXT,course TEXT,step TEXT,outcome TEXT,at INTEGER,PRIMARY KEY(user_id,revision,course,step));CREATE TABLE IF NOT EXISTS teaching_pilot_attempts(user_id TEXT,id TEXT,course TEXT,step TEXT,revision TEXT,result TEXT,created INTEGER,PRIMARY KEY(user_id,id));`);}
 get content(){if(!this._content){this._content=JSON.parse(fs.readFileSync(path.join(this.directory,'current.json')));if(this._content.schema!=='snow-speaks.teaching-pilot/1'||this._content.lessons.length!==2)fail(503,'试用课程正在准备中');}return this._content;}
 lesson(course){const l=this.content.lessons.find(l=>l.id===course);if(!l)fail(404,'试用课程不存在');return l;}
 oralStep(lesson,input){
  const base=lesson.steps.find(s=>s.id===input.step);if(!base)return null;
  if(base.interaction==='optional-word')return {...base,answers:input.practice===true?base.practiceAnswers:[]};
  if(base.interaction==='intent'){if(!['both','either'].includes(input.intent))fail(400,'请先选择这次想怎样装袋');return {...base,answers:[base.answers[input.intent==='both'?0:1]]};}
  return base;
 }
 sceneEvidence(user,course){return this.db.prepare('SELECT step,result FROM teaching_pilot_attempts WHERE user_id=? AND revision=? AND course=? ORDER BY created,rowid').all(user,this.content.revision,course).map(row=>({step:row.step,...JSON.parse(row.result)})).filter(r=>r.scene||r.status==='passed'||r.status==='assisted').map(r=>({step:r.step,scene:r.scene,status:r.status,level:r.evidenceLevel||'supported',heard:r.heard}));}
 async action(user,input){
  const l=this.lesson(input.course),step=l.steps.find(s=>s.id===input.step);if(input.revision!==this.content.revision||!step)fail(409,'场景已更新，请重新打开');
  if(!/^[a-zA-Z0-9-]{8,90}$/.test(input.attempt||''))fail(400,'操作标识无效');
  const old=this.db.prepare('SELECT course,step,revision,result FROM teaching_pilot_attempts WHERE user_id=? AND id=?').get(user,input.attempt);
  if(old){if(old.course!==l.id||old.step!==step.id||old.revision!==input.revision)fail(409,'操作标识不属于当前场景');return JSON.parse(old.result);}
  const r=sceneAction(step,input);r.message=this.content.messages[r.messageKey];r.audio=[this.content.narrationIds[r.message]].filter(Boolean);r.attempt=input.attempt;r.evidenceLevel='listening-action';
  if(step.interaction==='transform'&&r.status==='passed')r.audio.push(this.content.englishIds['despite the difficulty']);
  this.db.prepare('INSERT INTO teaching_pilot_attempts VALUES(?,?,?,?,?,?,?)').run(user,input.attempt,l.id,step.id,input.revision,JSON.stringify(r),this.store.now());return r;
 }
 asset(id,course){const l=this.lesson(course),c=this.content,a=c.assets[id];const permitted=new Set(l.steps.flatMap(s=>[s.narration,...s.audio]));for(const text of [...Object.values(c.guides),...Object.values(c.messages),...Object.values(soundTips)])permitted.add(c.narrationIds[text]);for(const value of Object.values(c.englishIds))permitted.add(value);if(!a||!permitted.has(id))fail(404,'试用声音不存在');
  const base=a.source==='formal'?this.curriculum.runtime(c.release).dir:this.directory,file=path.resolve(base,a.file);if(!file.startsWith(path.resolve(base)+path.sep))fail(503,'声音路径无效');const bytes=fs.readFileSync(file);if(bytes.length!==a.size||hash(bytes)!==a.sha256)fail(503,'试用声音校验失败');if(bytes.length>1500000)fail(503,'声音超过单段限制');return {kind:'teaching-pilot',revision:c.revision,voice:403008,id:a.id,text:a.text,language:a.language,sha256:a.sha256,size:a.size,cues:a.cues,speechEndMs:a.speechEndMs,inlineAudio:bytes.toString('base64')};}
 document(user,course){const l=this.lesson(course),revision=this.content.revision,visits=this.db.prepare('SELECT step,outcome FROM teaching_pilot_visits WHERE user_id=? AND revision=? AND course=?').all(user,revision,course);const review=[...new Map(this.db.prepare('SELECT step,result FROM teaching_pilot_attempts WHERE user_id=? AND revision=? AND course=? ORDER BY created').all(user,revision,course).map(r=>({...JSON.parse(r.result),step:r.step})).filter(r=>r.status==='repair').map(r=>[r.step,{step:r.step,word:r.word,type:r.type}])).values()];return {revision,...l,visits,review,englishIds:this.content.englishIds,words:this.curriculum.lesson(course,this.content.release).lesson.actualWords.map(w=>({word:w.word,ipa:w.ipa})),formalProgress:false,independentMastery:false};}
 ticket(user,id,course,step){const t=this.db.prepare('SELECT * FROM teaching_pilot_attempts WHERE user_id=? AND id=? AND course=? AND step=? AND revision=?').get(user,id,course,step,this.content.revision);if(!t||t.created<this.store.now()-1800000)fail(409,'局部练习已过期，请重新进入当前小段');return JSON.parse(t.result);}
 async oral(user,input){const c=this.content,l=this.lesson(input.course),step=this.oralStep(l,input);if(!step?.answers.length||input.revision!==c.revision)fail(409,'试用步骤已更新，请重新打开');if(!/^[a-zA-Z0-9-]{8,90}$/.test(input.attempt||''))fail(400,'练习标识无效');
  const started=performance.now(),timings={};
  const old=this.db.prepare('SELECT course,step,revision,result FROM teaching_pilot_attempts WHERE user_id=? AND id=?').get(user,input.attempt);if(old){if(old.course!==l.id||old.step!==step.id||old.revision!==c.revision)fail(409,'练习标识不属于当前步骤');return JSON.parse(old.result);}
  let target=null,previous=null;if(input.repair){previous=this.ticket(user,input.repair,input.course,input.step);if(previous.status!=='repair')fail(400,'局部练习无效');target=previous.target;}
  let assistance=null;if(input.assistance){assistance=this.ticket(user,input.assistance,input.course,input.step);if(assistance.status!=='assisted')fail(400,'辅助练习无效');}
  if(typeof input.wav!=='string'||input.wav.length>900000||!/^[A-Za-z0-9+/]*={0,2}$/.test(input.wav))fail(400,'录音格式无效');const wav=Buffer.from(input.wav,'base64');try{validateAudio(wav);}catch{fail(400,'没有获得有效录音，请再试一次');}
  if(this.inFlight.has(user)||this.inFlight.size>=3)fail(429,'上一段语音还在处理，请稍候');const now=this.store.now(),recent=(this.limits.get(user)||[]).filter(t=>t>now-60000);if(recent.length>=20)fail(429,'请稍后再试');this.limits.set(user,[...recent,now]);this.inFlight.add(user);
  let result,heard,firstHeard;try{
   const expected=target?[target]:step.answers;
   const reference=expected.find(a=>norm(a)===norm(input.reference||''))||expected[0];
   const measure=async(name,fn)=>{const t=performance.now();try{return await fn();}finally{timings[name]=Math.round(performance.now()-t);}};
   const [recognized,scored]=await Promise.allSettled([
    measure('asrMs',()=>this.recognizer(wav,{engine:'16k_en_large'})),
    measure('soeMs',()=>this.assessor(wav,{text:reference,language:'en',strictness:2}))
   ]);
   if(recognized.status==='rejected')fail(503,'语音识别服务暂未完成，这次不算读错，请重试');
   heard=recognized.value.text||'';
   let match=expected.find(a=>norm(a)===norm(heard));
   let assessment=scored.status==='fulfilled'?scored.value:null;
   if(match&&norm(match)!==norm(reference))assessment=await measure('alternateSoeMs',()=>this.assessor(wav,{text:match,language:'en',strictness:2}));
   if(match&&!assessment)fail(503,'发音评测服务暂未完成，这次不算读错，请重试');
   // Single words may be ambiguous to unrestricted ASR. Only strong independent
   // phone evidence can confirm the supplied word; retain the actual transcript.
   const strongWord=!match&&pilotTokens(reference).length===1&&assessment?.PronCompletion>=.98&&assessment?.PronAccuracy>=90&&assessment.Words?.length===1&&assessment.Words[0].MatchTag===0&&assessment.Words[0].PronAccuracy>=90&&assessment.Words[0].PhoneInfos?.length>0&&assessment.Words[0].PhoneInfos.every(p=>p.PronAccuracy>=80);
   if(!match&&!strongWord&&pilotDecision(step,heard,assessment,{target}).type==='wording'&&differences(pilotTokens(reference),pilotTokens(heard))<=2&&pilotDecision(step,reference,assessment,{target}).status==='passed'){
    firstHeard=heard;
    try{heard=(await measure('confirmationAsrMs',()=>this.fallbackRecognizer(wav,{engine:'16k_en_large'}))).text||'';}
    catch{fail(503,'两项语音结果不一致，暂时未能确认。这次不算读错，请再试一次');}
    match=expected.find(a=>norm(a)===norm(heard));
    if(match&&norm(match)!==norm(reference))assessment=await measure('alternateSoeMs',()=>this.assessor(wav,{text:match,language:'en',strictness:2}));
   }
   result=pilotDecision(step,strongWord?reference:heard,assessment,{target,available:w=>Object.hasOwn(c.englishIds,w)});
   if(strongWord)result.confirmedBy='strong-word-phoneme-evidence';
  }catch(e){if(e.status)throw e;fail(503,'语音服务暂时未能确认，这次不算读错，请重试');}finally{this.inFlight.delete(user);}
  timings.totalMs=Math.round(performance.now()-started);
  result={...result,heard,...(firstHeard?{firstHeard}:{}),timings,attempt:input.attempt,formalProgress:false,independentMastery:false,evidenceLevel:input.practice?'word-follow':step.transfer?'transfer':step.models.length?'followed-model':input.hint==='frame'?'frame-supported':'supported-expression'};
  if(!previous){const scene=sceneForSpeech(step,heard);if(scene)result.scene=scene;}
  if(result.status==='repair'){
   if(previous){result.target=target;result.original=previous.original;result.index=previous.index;result.word=previous.word;result.message='仍然只练当前这一小段。'+(result.message||'');}
   const guide=(result.phone&&soundTips[result.phone])||c.guides[result.word];result.message=result.message||c.messages[result.messageKey];if(guide&&!result.messageKey)result.message+=' 改法：'+guide;
   const narration=result.messageKey?c.messages[result.messageKey]:guide||c.messages.again;
   result.audio=[c.narrationIds[narration],c.englishIds[result.target]].filter(Boolean);result.repair=input.attempt;
   result.repairCount=(previous?.repairCount||0)+1;
   if(previous&&result.repairCount>=3){result.status='assisted';result.message=c.messages.assisted||'这一处先留作复习。现在看着完整提示，把刚才的意思连起来说。';result.audio=[c.narrationIds[c.messages.assisted||c.messages.again]].filter(Boolean);result.evidenceLevel='needs-review';}
  }else if(result.status==='passed'&&previous&&norm(previous.target)!==norm(previous.original)){result.returnToSentence=true;result.original=previous.original;result.message=c.messages.return;result.audio=[c.narrationIds[c.messages.return]];}
  else if(result.status==='unclear'){result.repair=input.repair||null;result.audio=[];}
  if(assistance&&result.status==='repair'){result.status='guided-complete';result.evidenceLevel='needs-review';result.message=c.messages.summaryReview;result.responseAudio=[c.narrationIds[c.messages.summaryReview]];}
  if(assistance&&result.status==='passed'&&!result.returnToSentence)result.evidenceLevel='assisted';
  if(result.status==='passed'&&!result.returnToSentence){const key=step.success==='packedChoice'?(result.scene?.bag?.length===2?'packedBoth':'packedEither'):step.success;if(key){result.message=c.messages[key];result.responseAudio=[c.narrationIds[result.message]].filter(Boolean);}}
  this.db.prepare('INSERT INTO teaching_pilot_attempts VALUES(?,?,?,?,?,?,?)').run(user,input.attempt,l.id,step.id,c.revision,JSON.stringify(result),now);return result;
 }
 async route(route,user,input,url){const course=url.searchParams.get('course')||input.course;
  if(route==='pilot/summary'){
   this.lesson(course);const events=this.db.prepare('SELECT step,result FROM teaching_pilot_attempts WHERE user_id=? AND revision=? AND course=? ORDER BY created,rowid').all(user,this.content.revision,course);
   const last=new Map(),issues=new Map(),lesson=this.lesson(course);
   for(const e of events){const r=JSON.parse(e.result);if(r.returnToSentence)continue;last.set(e.step,r);
    if(['repair','assisted','guided-complete'].includes(r.status))issues.set(e.step,r.type==='structure'?'despite 后接名词短语':r.word||lesson.steps.find(s=>s.id===e.step)?.display||'当前表达');
    if(r.status==='passed'&&r.evidenceLevel!=='assisted'){
     issues.delete(e.step);
     if(lesson.steps.find(s=>s.id===e.step)?.reviewTarget)for(const s of lesson.steps)if(norm(s.display)===norm(r.target))issues.delete(s.id);
    }
   }
   const counts={follow:0,supported:0,transfer:0},review=[...new Set(issues.values())],sentences=[];
   for(const [,r]of last){if(r.status==='passed'){if(r.evidenceLevel==='transfer')counts.transfer++;else if(r.evidenceLevel==='followed-model'||r.evidenceLevel==='word-follow')counts.follow++;else counts.supported++;if(r.heard)sentences.push(r.heard);}}
   const keys=[...(counts.follow?['summaryFollow']:[]),...(counts.supported?['summarySupported']:[]),...(counts.transfer?['summaryTransfer']:[]),...(review.length?['summaryReview']:[])];
   return {counts,review,sentences,audio:keys.map(k=>this.content.narrationIds[this.content.messages[k]]).filter(Boolean),independentMastery:false};
  }
  if(route==='pilot/catalog')return {revision:this.content.revision,courses:this.content.lessons.map(l=>({id:l.id,title:l.title,goal:l.goal})),formalProgress:false};
  if(route==='pilot/course')return {...this.document(user,course),sceneEvidence:this.sceneEvidence(user,course),flowEvidence:this.db.prepare('SELECT step,result FROM teaching_pilot_attempts WHERE user_id=? AND revision=? AND course=? ORDER BY created,rowid').all(user,this.content.revision,course).map(r=>({step:r.step,...JSON.parse(r.result)}))};
  if(route==='pilot/phoneme'){this.lesson(course);this.references??=new PhoneticReferences();return {asset:this.references.get(url.searchParams.get('symbol')),revision:this.content.revision};}
  if(route==='pilot/audio')return {asset:this.asset(url.searchParams.get('id'),course),revision:this.content.revision};
  if(route==='pilot/oral')return this.oral(user,input);
  if(route==='pilot/action')return this.action(user,input);
  if(route==='pilot/progress'){const step=this.lesson(course).steps.find(s=>s.id===input.step);if(input.revision!==this.content.revision||!step||!['heard','passed','assisted','skipped','not-needed'].includes(input.outcome))fail(400,'试用进度无效');if(['passed','assisted'].includes(input.outcome)){const r=this.ticket(user,input.attempt,course,step.id);const assistedPass=input.outcome==='assisted'&&((r.status==='passed'&&r.evidenceLevel==='assisted')||r.status==='guided-complete');if((r.status!==input.outcome&&!assistedPass)||r.returnToSentence)fail(400,'请先完成当前练习');}else if(input.outcome==='not-needed'&&!step.condition)fail(400,'本段不能自动省略');else if(input.outcome==='heard'&&((step.answers.length&&!step.optionalWindowMs)||['fruit-listen','transform','roster'].includes(step.interaction)))fail(400,'当前小段需要表达或操作，或明确跳过');this.db.prepare('INSERT OR REPLACE INTO teaching_pilot_visits VALUES(?,?,?,?,?,?)').run(user,this.content.revision,course,step.id,input.outcome,this.store.now());return {ok:true,formalProgress:false};}
  fail(404,'试用接口不存在');
 }
}
