import {learningDirectory} from './storage-paths.mjs';
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {DatabaseSync,backup} from 'node:sqlite';
import {projectRoot} from './tencent-speech.mjs';
export const hash=v=>crypto.createHash('sha256').update(v).digest('hex');
export const beijingDay=t=>new Date(t+28800000).toISOString().slice(0,10);
export function unionMs(rows){let end=-Infinity,total=0;for(const [a,b]of rows.sort((a,b)=>a[0]-b[0])){total+=Math.max(0,b-Math.max(a,end));end=Math.max(end,b);}return total;}
export class LearningStore{
 constructor({directory=learningDirectory,now=Date.now}={}){
 this.directory=directory;this.now=now;fs.mkdirSync(directory,{recursive:true,mode:0o700});this.db=new DatabaseSync(path.join(directory,'learning.sqlite'));
 this.db.exec(`PRAGMA journal_mode=WAL; PRAGMA busy_timeout=5000;
 CREATE TABLE IF NOT EXISTS meta(key TEXT PRIMARY KEY,value TEXT);
 CREATE TABLE IF NOT EXISTS activity(id TEXT PRIMARY KEY,user_id TEXT,session_id TEXT,start INTEGER,end INTEGER,active INTEGER,course TEXT,received INTEGER);
 CREATE INDEX IF NOT EXISTS activity_time ON activity(start,end,user_id);
 CREATE TABLE IF NOT EXISTS events(id TEXT PRIMARY KEY,user_id TEXT,at INTEGER,course TEXT,stage TEXT,type TEXT,detail TEXT);
 CREATE INDEX IF NOT EXISTS event_time ON events(at,user_id);
 CREATE TABLE IF NOT EXISTS checkpoints(user_id TEXT,course TEXT,payload TEXT,updated INTEGER,revision INTEGER DEFAULT 1,PRIMARY KEY(user_id,course));
 `);
 this.db.prepare('INSERT OR IGNORE INTO meta VALUES(?,?)').run('started',String(now()));
 }
 ingest(user,input,catalog){
 const now=this.now();let accepted=0;
 const allowed=new Set(catalog.courses.filter(c=>c.status==='published').map(c=>c.id));
 if(!Array.isArray(input.intervals)||input.intervals.length>500||!Array.isArray(input.events)||input.events.length>100)throw Object.assign(Error('上报格式错误'),{status:400});
 const ids=new Set(['start','stage','pass','correct','uncertain','help','skip','pause','finish','expose']);
 this.db.exec('BEGIN IMMEDIATE');try{
 for(const r of input.intervals){
 if(typeof r.id!=='string'||r.id.length>100||typeof r.session!=='string'||r.session.length>100||![r.start,r.end].every(Number.isSafeInteger)||r.end<=r.start||r.end-r.start>20000||r.end>now+60000||r.start<now-30*86400000||!(r.course===''||allowed.has(r.course)))continue;
 accepted+=Number(this.db.prepare('INSERT OR IGNORE INTO activity VALUES(?,?,?,?,?,?,?,?)').run(r.id,user,r.session,r.start,r.end,r.active===true?1:0,r.course,now).changes);
 }
 for(const r of input.events){
 if(typeof r.id!=='string'||r.id.length>100||!Number.isSafeInteger(r.at)||r.at>now+60000||r.at<now-30*86400000||!allowed.has(r.course)||!ids.has(r.type)||typeof r.stage!=='string'||r.stage.length>100)continue;
 this.db.prepare('INSERT OR IGNORE INTO events VALUES(?,?,?,?,?,?,?)').run(r.id,user,r.at,r.course,r.stage,r.type,JSON.stringify(r.detail||{}).length<=5000?JSON.stringify(r.detail||{}):'{}');
 }
 this.db.exec('COMMIT');return {accepted};
 }catch(e){this.db.exec('ROLLBACK');throw e;}
 }
 daily(from,to,user=''){
 const start=Date.parse(from+'T00:00:00+08:00'),end=Date.parse(to+'T00:00:00+08:00')+86400000;
 const rows=this.db.prepare('SELECT * FROM activity WHERE end>? AND start<? AND (?=\'\' OR user_id=?) ORDER BY start').all(start,end,user,user),groups=new Map();
 for(const r of rows){for(let a=Math.max(start,r.start);a<Math.min(end,r.end);){const day=beijingDay(a),b=Math.min(end,r.end,Date.parse(day+'T00:00:00+08:00')+86400000),key=r.user_id+':'+day;
 if(!groups.has(key))groups.set(key,{userId:r.user_id,date:day,all:[],allSessions:new Map(),active:[],activeSessions:new Map(),sessions:new Set(),courses:new Set(),first:a,last:b});const g=groups.get(key);g.all.push([a,b]);if(!g.allSessions.has(r.session_id))g.allSessions.set(r.session_id,[]);g.allSessions.get(r.session_id).push([a,b]);if(r.active){g.active.push([a,b]);if(!g.activeSessions.has(r.session_id))g.activeSessions.set(r.session_id,[]);g.activeSessions.get(r.session_id).push([a,b]);}g.sessions.add(r.session_id);if(r.course)g.courses.add(r.course);g.first=Math.min(g.first,a);g.last=Math.max(g.last,b);a=b;}}
 return [...groups.values()].map(g=>({userId:g.userId,date:g.date,foregroundMs:[...g.allSessions.values()].reduce((total,rows)=>total+unionMs(rows),0),learningMs:[...g.activeSessions.values()].reduce((total,rows)=>total+unionMs(rows),0),sessions:g.sessions.size,courses:g.courses.size,first:g.first,last:g.last}));
 }
 summary(user,catalog,{explored=[],completed=[],excludeCourses=new Set()}={}){
 const events=this.db.prepare('SELECT course,stage,type,detail FROM events WHERE user_id=?').all(user);
 const courses=new Set(),finished=new Set(),chapters=new Set(),words=new Set();
 const addWords=list=>{for(const word of list||[]){if(typeof word==='string'&&/^[a-z]+(?:'[a-z]+)?$/i.test(word)){const w=word.toLowerCase();words.add(({apples:'apple',bananas:'banana',eggs:'egg',cups:'cup',bags:'bag',dollars:'dollar',tickets:'ticket',sports:'sport',parents:'parent',dishes:'dish',teeth:'tooth',noodles:'noodle',learning:'learn',reading:'read',going:'go',visited:'visit',watched:'watch',sounds:'sound',fits:'fit',does:'do',am:'be',are:'be',is:'be',was:'be'})[w]||w);}}};
 const lookup=new Map(catalog.courses.map(c=>[c.id,c]));
 for(const event of events){
  if(excludeCourses.has(event.course))continue;
  if(['start','stage','finish'].includes(event.type))courses.add(event.course);
  if(event.type==='finish')finished.add(event.course);
  if(event.type==='stage'){
   const stage=lookup.get(event.course)?.stages?.find(s=>s.id===event.stage);
   if(stage?.chapter)chapters.add(lookup.get(event.course)?.category||event.course+':'+stage.chapter);
  }
  if(event.type==='expose'){try{addWords(JSON.parse(event.detail).words);}catch{}}
 }
 for(const course of explored){if(excludeCourses.has(course.id))continue;courses.add(course.id);if(course.category)chapters.add(course.category);}
 for(const id of completed)if(!excludeCourses.has(id))finished.add(id);
 for(const row of this.db.prepare('SELECT course,payload FROM checkpoints WHERE user_id=?').all(user)){
  if(excludeCourses.has(row.course))continue;
  try{addWords(JSON.parse(row.payload).vocabulary?.seen);}catch{}
 }
 const first=this.db.prepare('SELECT min(start) AS at FROM activity WHERE user_id=?').get(user).at;
 const today=beijingDay(this.now());
 const daily=first==null?[]:this.daily(beijingDay(first),today,user);
 const days=Array.from({length:7},(_,i)=>beijingDay(this.now()-(6-i)*86400000));
 const trend=days.map(date=>({date,learningMs:daily.find(r=>r.date===date)?.foregroundMs||0}));
 return {chapters:chapters.size,courses:courses.size,completedCourses:finished.size,words:words.size,learningDays:daily.filter(r=>r.foregroundMs>0).length,learningMs:daily.reduce((n,r)=>n+r.foregroundMs,0),averageDailyHours:trend.reduce((n,r)=>n+r.learningMs,0)/7/3600000,trend,updatedAt:this.now()};
 }
 async backup(){const dir=path.join(this.directory,'backups');fs.mkdirSync(dir,{recursive:true,mode:0o700});const file=path.join(dir,`learning-${beijingDay(this.now())}.sqlite`);await backup(this.db,file);return file;}
 close(){this.db.close();}
}
