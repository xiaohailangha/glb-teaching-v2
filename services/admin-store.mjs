import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {DatabaseSync,backup} from 'node:sqlite';
import {projectRoot} from './tencent-speech.mjs';
export const hash=v=>crypto.createHash('sha256').update(v).digest('hex');
export const beijingDay=t=>new Date(t+28800000).toISOString().slice(0,10);
export function unionMs(rows){let end=-Infinity,total=0;for(const [a,b]of rows.sort((a,b)=>a[0]-b[0])){total+=Math.max(0,b-Math.max(a,end));end=Math.max(end,b);}return total;}
export class AdminStore{
 constructor({directory=path.join(projectRoot,'work/admin-private'),now=Date.now}={}){
 this.directory=directory;this.now=now;fs.mkdirSync(directory,{recursive:true,mode:0o700});this.db=new DatabaseSync(path.join(directory,'management.sqlite'));
 this.db.exec(`PRAGMA journal_mode=WAL; PRAGMA busy_timeout=5000;
 CREATE TABLE IF NOT EXISTS meta(key TEXT PRIMARY KEY,value TEXT);
 CREATE TABLE IF NOT EXISTS admins(name TEXT PRIMARY KEY,salt TEXT,hash TEXT);
 CREATE TABLE IF NOT EXISTS admin_sessions(token TEXT PRIMARY KEY,name TEXT,expires INTEGER);
 CREATE TABLE IF NOT EXISTS login_hits(ip TEXT,at INTEGER);
 CREATE TABLE IF NOT EXISTS audit(id INTEGER PRIMARY KEY,at INTEGER,actor TEXT,action TEXT,target TEXT,result TEXT);
 CREATE TABLE IF NOT EXISTS activity(id TEXT PRIMARY KEY,user_id TEXT,session_id TEXT,start INTEGER,end INTEGER,active INTEGER,course TEXT,received INTEGER);
 CREATE INDEX IF NOT EXISTS activity_time ON activity(start,end,user_id);
 CREATE TABLE IF NOT EXISTS events(id TEXT PRIMARY KEY,user_id TEXT,at INTEGER,course TEXT,stage TEXT,type TEXT,detail TEXT);
 CREATE INDEX IF NOT EXISTS event_time ON events(at,user_id);
 CREATE TABLE IF NOT EXISTS checkpoints(user_id TEXT,course TEXT,payload TEXT,updated INTEGER,revision INTEGER DEFAULT 1,PRIMARY KEY(user_id,course));
 CREATE TABLE IF NOT EXISTS billing(month TEXT PRIMARY KEY,payload TEXT,updated INTEGER,error TEXT);
 `);
 this.db.prepare('INSERT OR IGNORE INTO meta VALUES(?,?)').run('started',String(now()));
 const file=path.join(projectRoot,'.secrets/admin-bootstrap.json');
 if(!this.db.prepare('SELECT 1 FROM admins LIMIT 1').get()&&fs.existsSync(file)){
 const c=JSON.parse(fs.readFileSync(file,'utf8'));if(/^[a-f0-9]{32}$/.test(c.salt)&&/^[a-f0-9]{128}$/.test(c.hash))this.db.prepare('INSERT INTO admins VALUES(?,?,?)').run('admin',c.salt,c.hash);
 }
 }
 audit(action,target='',result='成功',actor='admin'){this.db.prepare('INSERT INTO audit(at,actor,action,target,result) VALUES(?,?,?,?,?)').run(this.now(),actor,action,String(target).slice(0,120),result);}
 login(name,password,ip){
 this.db.prepare('DELETE FROM login_hits WHERE at<?').run(this.now()-900000);
 if(this.db.prepare('SELECT count(*) n FROM login_hits WHERE ip=?').get(hash(ip)).n>=8)throw Object.assign(Error('尝试过于频繁，请 15 分钟后再试'),{status:429});
 this.db.prepare('INSERT INTO login_hits VALUES(?,?)').run(hash(ip),this.now());
 const row=this.db.prepare('SELECT * FROM admins WHERE name=?').get(name);
 const check=crypto.scryptSync(String(password).slice(0,200),row?.salt||'invalid',64);
 if(!row||!crypto.timingSafeEqual(check,Buffer.from(row.hash,'hex'))){this.audit('登录','','失败');throw Object.assign(Error('账号或密码不正确'),{status:401});}
 this.db.prepare('DELETE FROM admin_sessions WHERE expires<?').run(this.now());
 const token=crypto.randomBytes(32).toString('base64url');this.db.prepare('INSERT INTO admin_sessions VALUES(?,?,?)').run(hash(token),name,this.now()+8*3600000);this.audit('登录');return token;
 }
 session(token){return token?this.db.prepare('SELECT name FROM admin_sessions WHERE token=? AND expires>?').get(hash(token),this.now()):null;}
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
 if(!groups.has(key))groups.set(key,{userId:r.user_id,date:day,all:[],active:[],sessions:new Set(),courses:new Set(),first:a,last:b});const g=groups.get(key);g.all.push([a,b]);if(r.active)g.active.push([a,b]);g.sessions.add(r.session_id);if(r.course)g.courses.add(r.course);g.first=Math.min(g.first,a);g.last=Math.max(g.last,b);a=b;}}
 return [...groups.values()].map(g=>({userId:g.userId,date:g.date,foregroundMs:unionMs(g.all),learningMs:unionMs(g.active),sessions:g.sessions.size,courses:g.courses.size,first:g.first,last:g.last}));
 }
 async backup(){const dir=path.join(this.directory,'backups');fs.mkdirSync(dir,{recursive:true,mode:0o700});const file=path.join(dir,`management-${beijingDay(this.now())}.sqlite`);await backup(this.db,file);return file;}
 close(){this.db.close();}
}
