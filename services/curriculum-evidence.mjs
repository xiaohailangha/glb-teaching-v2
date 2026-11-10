import crypto from 'node:crypto';
import {recognize,assess,validateAudio} from './tencent-speech.mjs';
const fail=(status,message)=>{throw Object.assign(Error(message),{status});};
export const normalizeAnswer=s=>String(s).toLowerCase().replace(/[’‘]/g,"'").replace(/\b(lynn)\b/g,'lin').replace(/\b(lee)\b/g,'li').replace(/[^a-z\u3400-\u9fff' /]/g,'').trim().replace(/\s+/g,' ').replace(/(?: (?:thanks|thank you))?(?: and you)?$/,'');
export function expressedWords(text){const words=new Set(normalizeAnswer(text).split(' '));if(words.has('okay'))words.add('ok');if(words.has("i'm")){words.add('i');words.add('be');}if(['am','is','are'].some(w=>words.has(w)))words.add('be');return words;}
export function oralDecision(check,heard,result){
 const matched=check.answers.some(a=>normalizeAnswer(a)===normalizeAnswer(heard));
 if(!matched)return {matched:false,reliable:false,reason:'未能确认这次回应。可以再说一次；自然的其他说法可交由人工核对。'};
 const words=result?.Words;
 if(!Array.isArray(words)||!words.length||words.some(w=>w.MatchTag!==0||!Number.isFinite(w.PronAccuracy)))return {matched:true,reliable:false,reason:'听到了符合情境的表达，但声音证据不足，请再试一次。'};
 const content=words.filter(w=>!['li','lee','lin','lynn','sam'].includes(String(w.Word).toLowerCase()));
 const score=content.reduce((n,w)=>n+w.PronAccuracy,0)/Math.max(1,content.length);
 const reliable=content.length>0&&score>=75&&content.every(w=>w.PronAccuracy>=60);
 return {matched:true,reliable,score,words:words.map(w=>({word:String(w.Word).toLowerCase(),status:w.PronAccuracy>=75?'good':'retry',score:w.PronAccuracy})),reason:reliable?'表达清楚，符合这个情境。':'表达意思符合情境，但这次发音证据还不足；无需模仿成同一种口音。'};
}

export class CurriculumEvidence {
 constructor(curriculum,{checks,words,steps,guidedLessons={},version,evidenceVersion='b101-evidence-v1',recognizer=recognize,assessor=assess}={}){
  Object.assign(this,{curriculum,db:curriculum.db,checks,words,steps,guidedLessons,version,evidenceVersion,recognizer,assessor});this.inFlight=new Set();this.limits=new Map();
  this.db.exec(`CREATE TABLE IF NOT EXISTS curriculum_challenges(id TEXT PRIMARY KEY,user_id TEXT,check_id TEXT,version TEXT,helped INTEGER,created INTEGER,heard TEXT DEFAULT '[]',result TEXT);
  CREATE TABLE IF NOT EXISTS curriculum_evidence(id TEXT PRIMARY KEY,user_id TEXT,check_id TEXT,word TEXT,variant TEXT,mode TEXT,at INTEGER,transcript TEXT,score REAL,version TEXT);
  CREATE INDEX IF NOT EXISTS curriculum_evidence_user ON curriculum_evidence(user_id,at);
  CREATE TABLE IF NOT EXISTS curriculum_steps(user_id TEXT,step TEXT,at INTEGER,PRIMARY KEY(user_id,step));`);
 }
 get now(){return this.curriculum.store.now();}
 challenge(user,input){
  const check=this.checks.find(c=>c.id===input.check&&c.course===input.course);if(!check)fail(400,'检查不存在');
  this.curriculum.checkCourse(user,check.course);if(input.version!==this.version)fail(409,'课程已更新，请刷新');
  this.db.prepare('DELETE FROM curriculum_challenges WHERE created<? AND result IS NULL').run(this.now-86400000);
  const recent=this.db.prepare('SELECT count(*) n FROM curriculum_challenges WHERE user_id=? AND created>?').get(user,this.now-60000).n;if(recent>=60)fail(429,'请稍后继续');
  const id=crypto.randomUUID();this.db.prepare('INSERT INTO curriculum_challenges(id,user_id,check_id,version,helped,created) VALUES(?,?,?,?,0,?)').run(id,user,check.id,this.version,this.now);
  const options=check.options?[...check.options]:undefined;
  if(options)for(let i=options.length-1;i>0;i--){const j=crypto.randomInt(i+1);[options[i],options[j]]=[options[j],options[i]];}
  return {id,check:check.id,options,audio:check.audio,prompt:check.prompt,mode:options?'choice':'oral',expiresAt:this.now+1800000};
 }
 get(user,id){const row=this.db.prepare('SELECT * FROM curriculum_challenges WHERE id=? AND user_id=?').get(id,user);if(!row)fail(404,'练习已失效，请重新开始');if(row.version!==this.version)fail(409,'课程已更新');if(row.created<this.now-1800000&&!row.result)fail(409,'练习已过期，请重新开始');return row;}
 hint(user,id){const r=this.get(user,id);if(!r.result)this.db.prepare('UPDATE curriculum_challenges SET helped=1 WHERE id=?').run(id);return {hint:this.checks.find(c=>c.id===r.check_id).hint,helped:true};}
 heard(user,input){const r=this.get(user,input.challenge),c=this.checks.find(c=>c.id===r.check_id);if(!c.audio.includes(input.audio))fail(400,'音频与当前题目不符');const ids=new Set(JSON.parse(r.heard));ids.add(input.audio);this.db.prepare('UPDATE curriculum_challenges SET heard=? WHERE id=?').run(JSON.stringify([...ids]),r.id);return {ok:true};}
 async answer(user,input){
  let r=this.get(user,input.challenge);if(r.result)return JSON.parse(r.result);
  const c=this.checks.find(c=>c.id===r.check_id);this.curriculum.checkCourse(user,c.course);
  if(c.audio.some(id=>!JSON.parse(r.heard).includes(id)))fail(409,'请先听完本题声音');
  if(this.inFlight.has(user)||this.inFlight.size>=3)fail(429,'上一段语音还在处理，请稍候');
  let text='',decision,mode=input.mode;
  if(c.options){if(mode!=='choice'||!c.options.includes(input.response))fail(400,'请选择本题的选项');text=input.response;decision={matched:c.answers.includes(text),reliable:c.answers.includes(text)};}
  else if(mode==='text'){if(typeof input.response!=='string'||input.response.length>200)fail(400,'回答无效');text=input.response;decision={matched:c.answers.some(a=>normalizeAnswer(a)===normalizeAnswer(text)),reliable:false};}
  else if(mode==='oral'){
   if(typeof input.wav!=='string'||input.wav.length>900000||!/^([A-Za-z0-9+/]{4})*([A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$/.test(input.wav))fail(400,'录音格式无效');
   const wav=Buffer.from(input.wav,'base64');try{validateAudio(wav);}catch{fail(400,'没有获得清晰有效的录音，请再试一次');}
   const recent=(this.limits.get(user)||[]).filter(t=>t>this.now-60000);if(recent.length>=20)fail(429,'请稍后再试');recent.push(this.now);this.limits.set(user,recent);this.inFlight.add(user);
   try{
    const heard=await this.recognizer(wav,{engine:'16k_en_large'});text=heard.text||'';
    if(c.answers.some(a=>normalizeAnswer(a)===normalizeAnswer(text))){
     const reference=text.replace(/[’‘]/g,"'").replace(/[^a-zA-Z\s.,!?'-]/g,'').trim();
     const result=await this.assessor(wav,{text:reference,language:'en',strictness:2});decision=oralDecision(c,text,result);
    }else decision=oralDecision(c,text,null);
   }catch{fail(503,'语音服务暂时未能确认；本次不会记失败，可重试');}finally{this.inFlight.delete(user);}
  }else fail(400,'作答方式无效');
  // Re-read after async evaluation: a hint opened while recording must invalidate independence.
  r=this.get(user,input.challenge);if(r.result)return JSON.parse(r.result);
  const independent=r.helped===0 && c.kind!=='teaching' && c.supported!==true && c.independentEligible!==false,verified=decision.reliable&&independent;
  const wordPassed=verified&&(!c.word||mode==='choice'||expressedWords(text).has(c.word));
  const result={matched:decision.matched,verified,wordPassed,mode,heard:text,score:decision.score??null,wordFeedback:decision.words||[],message:!independent?'已完成有提示练习；换一次独立尝试后再确认。':mode==='text'?'文字练习已记录，不代替口语通过。':decision.reason||(decision.matched?'理解正确，已记录本次独立证据。':'这次含义还需再辨认，听示范后换一次练习。')};
  this.db.exec('BEGIN IMMEDIATE');try{
   if(wordPassed)this.db.prepare('INSERT OR IGNORE INTO curriculum_evidence VALUES(?,?,?,?,?,?,?,?,?,?)').run(r.id,user,c.id,c.word||'',c.variant||'',mode,this.now,text,decision.score??null,this.evidenceVersion);
   // Passive word evidence comes only from a reliable, unassisted oral turn.
   // Context variants are server-authored, never accepted from the client.
   if(verified && mode==='oral' && c.passiveWords)for(const word of c.passiveWords){
    if(expressedWords(text).has(word))this.db.prepare('INSERT OR IGNORE INTO curriculum_evidence VALUES(?,?,?,?,?,?,?,?,?,?)').run(r.id+':'+word,user,c.id,word,c.contextVariant,mode,this.now,text,decision.score??null,this.evidenceVersion);
   }
   this.db.prepare('UPDATE curriculum_challenges SET result=? WHERE id=?').run(JSON.stringify(result),r.id);
   this.db.prepare('INSERT OR IGNORE INTO curriculum_trials VALUES(?,?,?,?,?,?,?,?)').run(user,r.id,c.course,c.id,mode,r.helped,text,this.now);
   this.db.exec('COMMIT');
  }catch(e){this.db.exec('ROLLBACK');throw e;}
  return {...result,progress:this.state(user)};
 }
 state(user){
  const rows=this.db.prepare('SELECT * FROM curriculum_evidence WHERE user_id=? AND version=? ORDER BY at').all(user,this.evidenceVersion);
  const passed=new Set(rows.map(r=>r.check_id));
  const visited=new Set(this.db.prepare('SELECT step FROM curriculum_steps WHERE user_id=?').all(user).map(s=>s.step));
  let completed=[...new Set(this.checks.filter(c=>!c.kind).map(c=>c.course))].filter(id=>this.checks.filter(c=>!c.kind&&c.course===id).every(c=>passed.has(c.id))&&this.steps.filter(s=>s.course===id&&!s.phase.includes('可延后')).every(s=>visited.has(s.id)));
  if(Object.keys(this.guidedLessons).length){
   const successful=new Set(this.db.prepare('SELECT check_id,result FROM curriculum_challenges WHERE user_id=? AND version=? AND result IS NOT NULL').all(user,this.version).filter(r=>JSON.parse(r.result).matched).map(r=>r.check_id));
   completed=Object.entries(this.guidedLessons).filter(([,flow])=>flow.every(s=>visited.has(s.id))&&flow.filter(s=>s.check).every(s=>successful.has(s.check))).map(([id])=>id);
  }
  const words=this.words.map(w=>{
   const key=w.word.toLowerCase(),e=rows.filter(r=>r.word===key),a=e.find(r=>r.variant==='a'),b=e.find(r=>r.variant==='b');
   const learned=!!a&&!!b,learnedAt=learned?Math.max(a.at,b.at):null;
   const later=learned?e.filter(r=>r.at>=learnedAt+86400000):[];
   const schedule=[1,7,30],pending=learned?schedule.find(day=>!e.some(r=>r.at>=learnedAt+day*86400000)):null;
   const dueAt=learned?pending?learnedAt+pending*86400000:(later.at(-1).at+30*86400000):null;
   return {word:key,sense:w.sense,learned,learnedAt,retained:later.length>0,dueAt,evidence: [...new Set(e.map(r=>r.variant))]};
  });
  // Capability edges are unlocked only when the specifically required evidence exists.
  const requirements={'B2.01':['C08'],'H1.01':['C06'],'F1.01':['C01','C04'],'T1.01':['C10'],'K1.01':['C01','C02'],'W1.01':['C08'],'B1.02':['C01','C02','C06','C10'],'B4.01':['C06']};
  for(const [target,ids] of Object.entries(requirements))if(ids.every(id=>passed.has(id)))this.db.prepare('INSERT OR IGNORE INTO curriculum_abilities VALUES(?,?,?,?,?)').run(user,'B1.01',target,'server-evaluated independent oral/listening checks: '+ids.join(','),this.now);
  return {completedCourses:completed,unitCompleted:completed.length===6,passed:[...passed],words,learnedWords:words.filter(w=>w.learned).length,dueWords:words.filter(w=>w.dueAt&&w.dueAt<=this.now).map(w=>w.word)};
 }
}
