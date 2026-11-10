import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import COS from 'cos-nodejs-sdk-v5';
import {projectRoot, credentials} from './tencent-speech.mjs';
import {CurriculumEvidence} from './curriculum-evidence.mjs';
import {correctDelivery} from './curriculum-delivery.mjs';
import {PhoneticReferences} from './phonetic-reference.mjs';

const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
const fail=(status,message)=>{throw Object.assign(Error(message),{status});};
const validId=id=>/^[a-f0-9]{64}$/.test(id||'');
const read=f=>JSON.parse(fs.readFileSync(f,'utf8'));
export class CloudCurriculum {
 constructor(store,{directory=path.join(projectRoot,'data/curriculum/cloud-runtime'),sign,recognizer,assessor}={}){
  this.store=store;this.db=store.db;this.directory=directory;this.sign=sign||signResources;this.recognizer=recognizer;this.assessor=assessor;this.releases=new Map();
  this.db.exec(`CREATE TABLE IF NOT EXISTS curriculum_trials(user_id TEXT,id TEXT,course TEXT,check_id TEXT,mode TEXT,helped INTEGER,response TEXT,at INTEGER,PRIMARY KEY(user_id,id));
   CREATE TABLE IF NOT EXISTS formal_profiles(user_id TEXT PRIMARY KEY,level INTEGER NOT NULL,revision INTEGER NOT NULL);
   CREATE TABLE IF NOT EXISTS formal_progress(user_id TEXT,release TEXT,course TEXT,step TEXT,revision INTEGER,updated INTEGER,PRIMARY KEY(user_id,release,course));
   CREATE TABLE IF NOT EXISTS formal_steps(user_id TEXT,release TEXT,course TEXT,step TEXT,at INTEGER,PRIMARY KEY(user_id,release,course,step));
   CREATE TABLE IF NOT EXISTS formal_heard(user_id TEXT,release TEXT,course TEXT,step TEXT,audio TEXT,at INTEGER,PRIMARY KEY(user_id,release,course,step,audio));
   CREATE TABLE IF NOT EXISTS formal_continued(user_id TEXT,release TEXT,course TEXT,step TEXT,at INTEGER,PRIMARY KEY(user_id,release,course,step));
   CREATE TABLE IF NOT EXISTS formal_skipped(user_id TEXT,release TEXT,course TEXT,step TEXT,at INTEGER,PRIMARY KEY(user_id,release,course,step));`);
 }
 active(){try{const id=read(path.join(this.directory,'current.json')).release;if(!validId(id))throw Error();return id;}catch{fail(503,'正式云课程正在准备中');}}
 runtime(id=this.active()){
  if(!validId(id))fail(400,'课程版本无效');if(this.releases.has(id))return this.releases.get(id);
  const dir=path.join(this.directory,'releases',id);let bytes;try{bytes=fs.readFileSync(path.join(dir,'index.json'));}catch{fail(409,'课程版本已不可用，请重新打开');}
  if(hash(bytes)!==id)fail(503,'课程索引校验失败');const index=JSON.parse(bytes);if(index.schema!=='snow-speaks.cloud-curriculum/1'||index.catalog.courses.length!==555)fail(503,'正式课程目录无效');
  const courses=new Map(index.catalog.courses.map(c=>[c.id,c])),units=new Map(index.catalog.units.map(u=>[u.id,u]));const runtime={id,dir,index,courses,units,documents:new Map(),signed:new Map()};this.releases.set(id,runtime);return runtime;
 }
 lesson(id,release){const r=this.runtime(release);if(!r.courses.has(id))fail(404,'正式课程不存在');if(r.documents.has(id))return r.documents.get(id);const descriptor=r.index.lessons[id],bytes=fs.readFileSync(path.join(r.dir,descriptor.path));if(hash(bytes)!==descriptor.sha256)fail(503,'课程内容校验失败');const student=JSON.parse(bytes),teacherBytes=fs.readFileSync(path.join(r.dir,'teacher',id+'.json'));if(hash(teacherBytes)!==descriptor.sourceSha256)fail(503,'教学依据校验失败');const lesson=JSON.parse(teacherBytes);if(lesson.courseId!==id||lesson.planHash!==r.index.catalog.planHash)fail(503,'课程与正式规划不一致');const value={...correctDelivery(lesson,student),descriptor};r.documents.set(id,value);return value;}
 evidence(release){const r=this.runtime(release);if(r.evidence)return r.evidence;const lessons=r.index.catalog.courses.map(c=>this.lesson(c.id,r.id).lesson),checks=lessons.flatMap(l=>l.checks.map(c=>{
  const step=l.steps.find(s=>s.check===c.id),model=step?.model;return {...c,audio:[...new Set([...(c.audio||[]),...(model?[model]:[])])]};}));
  const curriculum={db:this.db,store:this.store,checkCourse:(user,id)=>this.checkCourse(user,id,r.id)};
  const evidence=new CurriculumEvidence(curriculum,{checks,words:[],steps:lessons.flatMap(l=>l.steps),version:r.id,evidenceVersion:'formal-guided-'+r.id,...(this.recognizer?{recognizer:this.recognizer}:{}),...(this.assessor?{assessor:this.assessor}:{})});
  // The source has guided teaching only. Neither a matched answer nor a
  // completed lesson mints independent mastery or a learned-word total.
  evidence.state=user=>this.evidenceState(user,r.id);r.evidence=evidence;return evidence;
 }
 progressStatus(user,release){const r=this.runtime(release),visited=new Set(this.db.prepare('SELECT step FROM formal_steps WHERE user_id=? AND release=?').all(user,r.id).map(x=>x.step)),matched=new Set(this.db.prepare('SELECT check_id,result FROM curriculum_challenges WHERE user_id=? AND version=? AND result IS NOT NULL').all(user,r.id).filter(x=>JSON.parse(x.result).matched).map(x=>x.check_id)),continued=new Set(this.db.prepare('SELECT step FROM formal_continued WHERE user_id=? AND release=?').all(user,r.id).map(x=>x.step));
  const skipped=new Set(this.db.prepare('SELECT step FROM formal_skipped WHERE user_id=? AND release=?').all(user,r.id).map(x=>x.step));
  return new Map(r.index.catalog.courses.map(c=>{const l=this.lesson(c.id,r.id).lesson,done=s=>skipped.has(s.id)||visited.has(s.id)&&(!s.check||matched.has(s.check)||continued.has(s.id)),pendingStep=l.steps.find(s=>!done(s))?.id??null;return [c.id,{pendingStep,completed:pendingStep===null,visitedSteps:l.steps.filter(done).map(s=>s.id),skippedSteps:l.steps.filter(s=>skipped.has(s.id)).map(s=>s.id)}];}));
 }
 evidenceState(user,release,status=this.progressStatus(user,release)){
  const completed=[...status].filter(([,p])=>p.completed).map(([id])=>id);
  return {completedCourses:completed,unitCompleted:false,learnedWords:0,words:[],dueWords:[],passed:[],basis:[...status.values()].some(p=>p.skippedSteps.length)?'guided_teaching_with_explicit_skips':'guided_teaching_only',independentMastery:false};
 }
 state(user,release){const r=this.runtime(release);this.evidence(r.id);const status=this.progressStatus(user,r.id),p=this.db.prepare('SELECT level,revision FROM formal_profiles WHERE user_id=?').get(user)||{level:null,revision:0};return {...p,version:r.id,progress:this.db.prepare('SELECT course,step,revision,updated FROM formal_progress WHERE user_id=? AND release=?').all(user,r.id).map(p=>({...p,...status.get(p.course)})),evidence:this.evidenceState(user,r.id,status),opened:[],trialCount:this.db.prepare('SELECT count(*) n FROM curriculum_trials WHERE user_id=? AND course LIKE ?').get(user,'N26-%').n,abilities:[]};}
 selectLevel(user,input){if(!Number.isInteger(input.level)||input.level<1||input.level>5)fail(400,'请选择有效的学习起点');const p=this.state(user,input.version);if(p.revision!==input.revision)fail(409,'学习起点已更新，请刷新');this.db.prepare('INSERT OR REPLACE INTO formal_profiles VALUES(?,?,?)').run(user,input.level,p.revision+1);return this.state(user,input.version);}
 checkCourse(user,id,release){const r=this.runtime(release),c=r.courses.get(id);if(!c)fail(404,'正式课程不存在');const complete=new Set(this.evidenceState(user,r.id).completedCourses),profile=this.db.prepare('SELECT level FROM formal_profiles WHERE user_id=?').get(user);if(!profile)fail(403,'请先选择学习起点');
  for(const dep of c.prerequisites){const required=r.courses.has(dep)?[dep]:r.units.get(dep)?.courses;if(!required)fail(503,'正式前置关系无效');if(required.some(id=>!complete.has(id)))fail(403,'请先完成前置课程，再开始本课');}
  const l=this.lesson(id,r.id).lesson;
  for(const ref of l.requiredTaughtWords||[]){
   if(ref.planHash!==l.planHash)fail(503,'首教来源版本不一致');
   const original=this.lesson(ref.sourceCourse,r.id).lesson,words=original.actualWords.filter(w=>w.key===ref.key);
   const normalized=s=>String(s).toLowerCase().replace(/[.,!?。！？]/g,'').trim();
   const ids=[...new Set([...words.map(w=>w.audio),...original.steps.filter(s=>s.phase==='示范'&&normalized(s.display)===normalized(ref.key)).map(s=>s.audio)])];
   const heard=ids.some(audio=>this.db.prepare('SELECT 1 FROM formal_heard WHERE user_id=? AND release=? AND course=? AND audio=?').get(user,r.id,ref.sourceCourse,audio));
   const explicitlySkipped=original.steps.some(s=>(ids.includes(s.audio)||ids.includes(s.model))&&this.db.prepare('SELECT 1 FROM formal_skipped WHERE user_id=? AND release=? AND course=? AND step=?').get(user,r.id,ref.sourceCourse,s.id));
   if(!heard&&!explicitlySkipped)fail(403,'请先学习本课所需词语，或使用右箭头跳过相应教学段');
  }
  return c;
 }
 catalog(release){const r=this.runtime(release);return {...r.index.catalog,types:r.index.catalog.categories.map(c=>({id:c.name,title:c.name,courseIds:r.index.catalog.courses.filter(x=>x.category===c.name).map(x=>x.id)})),version:r.id,release:r.id,sourceArchiveRelease:r.index.sourceArchiveRelease,status:'published',formal:true,levels:[1,2,3,4,5].map(level=>({level,name:'学习起点 '+level})),mediaMode:'per-course'};}
 async detail(id,release,{user,preview=false}={}){const r=this.runtime(release);if(!preview)this.checkCourse(user,id,r.id);const {descriptor,student,deliveryRevision}=this.lesson(id,r.id);const key=`courses/releases/${r.id}/runtime/lessons/${id}.${descriptor.sha256}.json`;const [asset]=await this.sign([{key,sha256:descriptor.sha256,size:descriptor.size}]);const bytes=Buffer.from(JSON.stringify(student));return {release:r.id,sourceArchiveRelease:r.index.sourceArchiveRelease,course:id,resource:asset,deliveryRevision,inlineDocument:{base64:bytes.toString('base64'),sha256:hash(bytes),size:bytes.length},expiresAt:this.store.now()+900000};}
 async media(id,release,{user,preview=false}={}){const r=this.runtime(release);if(!preview)this.checkCourse(user,id,r.id);const {student}=this.lesson(id,r.id),cacheKey=id;const hit=r.signed.get(cacheKey);if(hit&&hit.expiresAt>this.store.now()+60000)return hit;const assets=await this.sign(student.audio.map(a=>({...a,key:`courses/releases/${r.id}/runtime/${r.index.audio[a.id].path}`})));const value={release:r.id,id:r.id,course:id,expiresAt:this.store.now()+900000,assets};r.signed.set(cacheKey,value);return value;}
 heard(user,input){const r=this.runtime(input.version);this.checkCourse(user,input.course,r.id);const {lesson}=this.lesson(input.course,r.id),step=lesson.steps.find(s=>s.id===input.step);if(!step)fail(400,'教学步骤无效');const help=lesson.helpBranches.find(h=>h.forStep===step.id),allowed=[step.audio,step.model,help?.audio,help?.model,help?.onRepeatedDifficulty?.audio].filter(Boolean);if(!allowed.includes(input.audio))fail(400,'声音与当前教学步骤不一致');if(input.challenge){const row=this.evidence(r.id).get(user,input.challenge);if(row.check_id!==step.check||!this.evidence(r.id).checks.find(c=>c.id===row.check_id)?.audio.includes(input.audio))fail(400,'练习与当前课程步骤不一致');}this.db.prepare('INSERT OR REPLACE INTO formal_heard VALUES(?,?,?,?,?,?)').run(user,r.id,input.course,input.step,input.audio,this.store.now());const previous=lesson.steps[lesson.steps.indexOf(step)-1];if(step.check&&previous?.phase==='示范'&&previous.audio===input.audio)this.db.prepare('INSERT OR REPLACE INTO formal_heard VALUES(?,?,?,?,?,?)').run(user,r.id,input.course,previous.id,input.audio,this.store.now());if(input.challenge)this.evidence(r.id).heard(user,input);return {ok:true,independentMastery:false};}
 saveProgress(user,input){const r=this.runtime(input.version);this.checkCourse(user,input.course,r.id);const l=this.lesson(input.course,r.id).lesson,s=l.steps.find(s=>s.id===input.step);if(!s)fail(400,'教学步骤无效');
  const skip=input.skipped===true;
  if(!skip&&s.audio&&!this.db.prepare('SELECT 1 FROM formal_heard WHERE user_id=? AND release=? AND course=? AND step=? AND audio=?').get(user,r.id,input.course,s.id,s.audio))fail(409,'请先听完本步声音');
  if(!skip&&s.check){const passed=this.db.prepare('SELECT result FROM curriculum_challenges WHERE user_id=? AND check_id=? AND version=? AND result IS NOT NULL').all(user,s.check,r.id).some(x=>JSON.parse(x.result).matched);const continued=this.db.prepare('SELECT 1 FROM formal_continued WHERE user_id=? AND release=? AND course=? AND step=?').get(user,r.id,input.course,s.id);if(!passed&&!continued)fail(409,'请先完成本步练习，或点击右箭头跳过');}
  const previous=l.steps[l.steps.indexOf(s)-1],skippedSteps=skip?[...(s.check&&previous?.phase==='示范'&&previous.audio===s.model?[previous.id]:[]),s.id]:[];
  const old=this.db.prepare('SELECT revision FROM formal_progress WHERE user_id=? AND release=? AND course=?').get(user,r.id,input.course);if((old?.revision||0)!==input.revision)fail(409,'另一设备已更新学习位置，请重新打开');const revision=(old?.revision||0)+1;this.db.exec('BEGIN IMMEDIATE');try{if(skip){for(const step of skippedSteps)if(!this.db.prepare('SELECT 1 FROM formal_steps WHERE user_id=? AND release=? AND course=? AND step=?').get(user,r.id,input.course,step))this.db.prepare('INSERT OR REPLACE INTO formal_skipped VALUES(?,?,?,?,?)').run(user,r.id,input.course,step,this.store.now());}else this.db.prepare('INSERT OR REPLACE INTO formal_steps VALUES(?,?,?,?,?)').run(user,r.id,input.course,input.step,this.store.now());this.db.prepare('INSERT OR REPLACE INTO formal_progress VALUES(?,?,?,?,?,?)').run(user,r.id,input.course,input.step,revision,this.store.now());this.db.exec('COMMIT');}catch(e){this.db.exec('ROLLBACK');throw e;}return {revision,...(skip?{skipped:true,skippedSteps,awardMastery:false}: {})};}
 continueListening(user,input){const r=this.runtime(input.version);this.checkCourse(user,input.course,r.id);const l=this.lesson(input.course,r.id).lesson,s=l.steps.find(s=>s.id===input.step),help=l.helpBranches.find(h=>h.forStep===s?.id);if(!s?.check||help?.onRepeatedDifficulty?.allowListenAndContinue!==true||help.onRepeatedDifficulty.awardMastery!==false)fail(400,'当前步骤没有听后继续分支');if(!this.db.prepare('SELECT 1 FROM formal_heard WHERE user_id=? AND release=? AND course=? AND step=? AND audio=?').get(user,r.id,input.course,s.id,s.model))fail(409,'请先听完本步示范');this.db.prepare('INSERT OR REPLACE INTO formal_continued VALUES(?,?,?,?,?)').run(user,r.id,input.course,s.id,this.store.now());return {continued:true,verified:false,awardMastery:false};}
 trials(user){return this.db.prepare('SELECT id,course,check_id,mode,helped,response,at FROM curriculum_trials WHERE user_id=? AND course LIKE ? ORDER BY at DESC LIMIT 100').all(user,'N26-%');}
 async route(route,user,input,url){const release=input.version||url.searchParams.get('release')||this.active();const r=this.runtime(release),e=this.evidence(r.id);if(route==='curriculum')return {...this.catalog(r.id),state:this.state(user,r.id)};
  if(route==='curriculum/state')return this.state(user,r.id);if(route==='curriculum/course')return this.detail(url.searchParams.get('course'),r.id,{user});if(route==='curriculum/media')return this.media(url.searchParams.get('course'),r.id,{user});
  if(route==='curriculum/phoneme'){const course=url.searchParams.get('course');this.checkCourse(user,course,r.id);this.phoneticReferences??=new PhoneticReferences();return {release:r.id,course,asset:this.phoneticReferences.get(url.searchParams.get('symbol'))};}
  if(route==='curriculum/start')return this.selectLevel(user,{...input,version:r.id});if(route==='curriculum/progress')return this.saveProgress(user,{...input,skipped:false});if(route==='curriculum/skip')return this.saveProgress(user,{...input,skipped:true});if(route==='curriculum/heard')return this.heard(user,input);if(route==='curriculum/continue')return this.continueListening(user,input);
  if(route==='curriculum/challenge')return {...e.challenge(user,input),release:r.id};
  if(['curriculum/hint','curriculum/answer','curriculum/oral'].includes(route)){e.get(user,input.challenge);if(route==='curriculum/hint')return e.hint(user,input.challenge);return e.answer(user,input);}fail(404,'接口不存在');
 }
 status(){const r=this.runtime();return {active:r.id,sourceArchiveRelease:r.index.sourceArchiveRelease,courseCount:555,audioCount:Object.keys(r.index.audio).length,delivery:'private-cos-per-course',masteryClaimed:false,created:fs.statSync(path.join(r.dir,'index.json')).mtimeMs,bytes:[...new Map(Object.values(r.index.audio).map(a=>[a.sha256,a])).values()].reduce((n,a)=>n+a.size,0)+Object.values(r.index.lessons).reduce((n,l)=>n+l.size,0)};}
}
async function signResources(assets){const cfg=read(path.join(projectRoot,'.secrets/cos-scene-assets.json')),c=credentials(),cos=new COS({SecretId:c.secretId,SecretKey:c.secretKey,Protocol:'https:'});return Promise.all(assets.map(a=>new Promise((resolve,reject)=>cos.getObjectUrl({Bucket:cfg.bucket,Region:cfg.region,Key:a.key,Sign:true,Expires:900,Protocol:'https:'},(e,r)=>e?reject(e):resolve({...a,url:r.Url})))));}
