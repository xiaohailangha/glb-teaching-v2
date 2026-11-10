import fs from 'node:fs';
import crypto from 'node:crypto';
import {formalCatalog,formalPlan,formalPlanVersion,testCourseIds,emptyFormalEvidence,validateFormalPlan} from './formal-curriculum.mjs';

const read=name=>JSON.parse(fs.readFileSync(new URL(`../data/curriculum/${name}.json`,import.meta.url),'utf8'));
export const plan=formalPlan;
const testPlan=read('plan-3000'),access=read('access'),sample=read('sample');
export {access,sample};
export const runtimeChecks=[...read('checks').map(c=>({...sample.checks.find(s=>s.id===c.id),...c})),...read('word-checks')];
export const curriculumVersion=crypto.createHash('sha256').update(JSON.stringify([testPlan,access,sample,runtimeChecks])).digest('hex').slice(0,16);
const fail=(status,message)=>{throw Object.assign(Error(message),{status});};
export function validateCurriculum(){
 validateFormalPlan();
 const units=new Map(testPlan.units.map(u=>[u.id,u])),courses=new Map(testPlan.courses.map(c=>[c.id,c]));
 if(units.size!==79||courses.size!==505||new Set(testPlan.lexicon.map(w=>w.key)).size!==3000||testPlan.categories.length!==12)throw Error('课程规划数量错误');
 const seen=new Set(),visiting=new Set();
 const walk=id=>{if(visiting.has(id))throw Error('循环前置');if(seen.has(id))return;visiting.add(id);const u=access.units.find(u=>u.id===id);if(!u||!units.has(id))throw Error('缺少单元');for(const p of u.prerequisites)walk(p.unit);visiting.delete(id);seen.add(id);};
 for(const u of testPlan.units){walk(u.id);for(const id of u.courses)if(courses.get(id)?.unit!==u.id)throw Error('课程归属错误');}
 for(const w of testPlan.lexicon)if(!courses.get(w.course)?.new.includes(w.key))throw Error('首教词分配错误');
 const audio=new Set(sample.audio.map(a=>a.id));
 for(const s of sample.steps)if(!courses.has(s.course)||(s.audio&&s.audio.split('、').some(id=>!audio.has(id))))throw Error('脚本引用错误');
 for(const c of runtimeChecks)if((!['word','teaching'].includes(c.kind)&&!sample.checks.some(s=>s.id===c.id))||!courses.has(c.course)||c.audio.some(id=>!audio.has(id)))throw Error('检查引用错误');
 return true;
}
validateCurriculum();

// Draft content is distinct from the immutable, audio-reviewed COS release.
export function curriculumCatalog(){return {...formalCatalog(),version:curriculumVersion,levels:access.levels,testData:{scope:'experience-test',countsTowardFormal:false,units:testPlan.units.filter(u=>u.id==='B1.01').map(u=>({...u,...access.units.find(a=>a.id===u.id),status:'test'})),courses:testPlan.courses.filter(c=>testCourseIds.has(c.id)).map(c=>({...c,...sample.lessons.find(l=>l.id===c.id),title:sample.lessons.find(l=>l.id===c.id)?.name||c.title,status:'test'})),sample:{...sample,checks:runtimeChecks.map(c=>({...c,answers:undefined}))}}};}
const normalize=s=>s.trim().toLowerCase().replace(/[’‘]/g,"'").replace(/[.!?，。！?]/g,'').replace(/\s+/g,' ');

export class CurriculumStore {
 constructor(store){this.store=store;this.db=store.db;this.db.exec(`
 CREATE TABLE IF NOT EXISTS curriculum_profiles(user_id TEXT PRIMARY KEY,level INTEGER NOT NULL,revision INTEGER NOT NULL);
 CREATE TABLE IF NOT EXISTS curriculum_open(user_id TEXT,unit TEXT,PRIMARY KEY(user_id,unit));
 CREATE TABLE IF NOT EXISTS curriculum_progress(user_id TEXT,course TEXT,step TEXT,revision INTEGER,updated INTEGER,PRIMARY KEY(user_id,course));
 CREATE TABLE IF NOT EXISTS curriculum_trials(user_id TEXT,id TEXT,course TEXT,check_id TEXT,mode TEXT,helped INTEGER,response TEXT,at INTEGER,PRIMARY KEY(user_id,id));
 CREATE TABLE IF NOT EXISTS curriculum_abilities(user_id TEXT,source TEXT,target TEXT,note TEXT,at INTEGER,PRIMARY KEY(user_id,source,target));
 `);}
 testState(user){
  const evidence=this.evidence?.state(user);
  const p=this.db.prepare('SELECT level,revision FROM curriculum_profiles WHERE user_id=?').get(user)||{level:null,revision:0};
  const abilities=this.db.prepare('SELECT source,target FROM curriculum_abilities WHERE user_id=?').all(user);
  const opened=new Set(this.db.prepare('SELECT unit FROM curriculum_open WHERE user_id=?').all(user).map(r=>r.unit));
  if(p.level!==null)for(const u of access.units)if(u.level<=p.level||u.prerequisites.length>0&&u.prerequisites.every(d=>abilities.some(a=>a.source===d.unit&&a.target===u.id)))opened.add(u.id);
  for(const id of opened)this.db.prepare('INSERT OR IGNORE INTO curriculum_open VALUES(?,?)').run(user,id);
  return {...p,version:curriculumVersion,opened:[...opened],progress:this.db.prepare('SELECT course,step,revision,updated FROM curriculum_progress WHERE user_id=?').all(user),trialCount:this.db.prepare('SELECT count(*) n FROM curriculum_trials WHERE user_id=?').get(user).n,abilities,evidence};
 }
 state(user){
  const testData=this.testState(user);
  // Historical test rows stay in place, but cannot open a formal dependency or
  // contribute words/completions to the new curriculum. No history is deleted.
  return {level:testData.level,revision:testData.revision,version:formalPlanVersion,opened:formalPlan.units.filter(u=>testData.level!==null&&u.stage<=testData.level).map(u=>u.id),progress:[],trialCount:0,abilities:[],evidence:emptyFormalEvidence(),testData:{...testData,scope:'experience-test',countsTowardFormal:false}};
 }
 selectLevel(user,input){
  if(!Number.isInteger(input.level)||input.level<1||input.level>5)fail(400,'请选择有效的学习起点');
  this.db.exec('BEGIN IMMEDIATE');try{const p=this.state(user);if(input.revision!==p.revision)fail(409,'学习起点已在其他设备更新，请刷新');this.db.prepare('INSERT OR REPLACE INTO curriculum_profiles VALUES(?,?,?)').run(user,input.level,p.revision+1);const result=this.state(user);this.db.exec('COMMIT');return result;}catch(e){this.db.exec('ROLLBACK');throw e;}
 }
 checkCourse(user,id){const course=testPlan.courses.find(c=>c.id===id);if(!course||!testCourseIds.has(id)||!sample.lessons.some(l=>l.id===id))fail(409,'课程尚未完成编写');if(!this.testState(user).opened.includes(course.unit))fail(403,'请先完成必要能力或选择学习起点');return course;}
 saveProgress(user,input){
  this.checkCourse(user,input.course);
  if(input.version!==curriculumVersion)fail(409,'课程已更新，请重新打开');
  if(![...sample.steps,...Object.values(sample.guidedLessons||{}).flat()].some(s=>s.course===input.course&&s.id===input.step))fail(400,'教学步骤无效');
  this.db.exec('BEGIN IMMEDIATE');try{const old=this.db.prepare('SELECT revision FROM curriculum_progress WHERE user_id=? AND course=?').get(user,input.course);if((old?.revision||0)!==input.revision)fail(409,'另一设备已更新学习位置，请刷新');const revision=(old?.revision||0)+1;this.db.prepare('INSERT OR REPLACE INTO curriculum_progress VALUES(?,?,?,?,?)').run(user,input.course,input.step,revision,this.store.now());if(this.evidence)this.db.prepare('INSERT OR REPLACE INTO curriculum_steps VALUES(?,?,?)').run(user,input.step,this.store.now());this.db.exec('COMMIT');return {revision};}catch(e){this.db.exec('ROLLBACK');throw e;}
 }
 recordTrial(user,input){
  this.checkCourse(user,input.course);
  if(input.version!==curriculumVersion)fail(409,'课程已更新，请重新打开');
  if(!sample.checks.some(c=>c.course===input.course&&c.id===input.check)||!['text','choice','spoken-self-report'].includes(input.mode)||typeof input.helped!=='boolean'||typeof input.id!=='string'||!/^[a-zA-Z0-9_-]{8,100}$/.test(input.id)||typeof input.response!=='string'||!input.response.trim()||input.response.length>500)fail(400,'练习记录无效');
  const check=runtimeChecks.find(c=>c.id===input.check);
  if(input.mode==='choice'&&!check.options?.includes(input.response))fail(400,'选项无效');
  const matched=check.answers.some(a=>normalize(a)===normalize(input.response));
  const old=this.db.prepare('SELECT * FROM curriculum_trials WHERE user_id=? AND id=?').get(user,input.id);
  if(old&&(old.course!==input.course||old.check_id!==input.check||old.response!==input.response.trim()||old.mode!==input.mode||old.helped!==(input.helped?1:0)))fail(409,'练习编号已使用，请重新提交');
  this.db.prepare('INSERT OR IGNORE INTO curriculum_trials VALUES(?,?,?,?,?,?,?,?)').run(user,input.id,input.course,input.check,input.mode,input.helped?1:0,input.response.trim(),this.store.now());
  // Neither self-report nor a text answer establishes independent oral ability.
  return {saved:true,verified:false,matched,message:matched?'表达符合本题；练习已保存，口语能力待核验':'已记录这次尝试。可以查看提示再练；不同的自然说法留待人工确认。'};
 }
 reviewAbility(user,input){
  const edge=access.units.find(u=>u.id===input.target)?.prerequisites.find(p=>p.unit===input.source);
  if(!edge||input.source!=='B1.01'||input.mode!=='observed-oral'||input.independent!==true||typeof input.note!=='string'||input.note.trim().length<10||input.note.length>1000)fail(400,'请提供独立口头检查的实际观察记录');
  this.db.prepare('INSERT OR REPLACE INTO curriculum_abilities VALUES(?,?,?,?,?)').run(user,input.source,input.target,input.note.trim(),this.store.now());return this.state(user);
 }
 trials(user){if(!this.evidence)return this.db.prepare('SELECT * FROM curriculum_trials WHERE user_id=? ORDER BY at DESC LIMIT 100').all(user);return this.db.prepare('SELECT t.*,c.result FROM curriculum_trials t LEFT JOIN curriculum_challenges c ON t.id=c.id AND t.user_id=c.user_id WHERE t.user_id=? ORDER BY t.at DESC LIMIT 100').all(user).map(r=>({...r,result:r.result?JSON.parse(r.result):null}));}
}
