import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {backup} from 'node:sqlite';
import {LearningStore,beijingDay} from './learning-store.mjs';
import {CloudCurriculum} from './cloud-curriculum.mjs';
import {TeachingPilot} from './teaching-pilot.mjs';
import {getAuthStore,learnerCookie} from './auth-http.mjs';
import {projectRoot,configured} from './tencent-speech.mjs';
const json=(res,status,data)=>res.writeHead(status,{'Content-Type':'application/json; charset=utf-8','Cache-Control':'no-store'}).end(JSON.stringify(data));
const error=(status,message)=>{throw Object.assign(Error(message),{status});};
export function createLearningHttp(store,auth,{secure=true,catalog=null,bridgeToken='',content=null}={}){
 const curriculum=new CloudCurriculum(store);
 const pilot=new TeachingPilot(store,curriculum);
 function formalSummary(user){
  const state=curriculum.state(user),completed=state.evidence.completedCourses;
  const ids=new Set([...state.progress.map(p=>p.course),...completed]);
  const explored=catalog.courses.filter(c=>ids.has(c.id));
  return {...store.summary(user,catalog,{explored,completed}),courses:explored.length,chapters:new Set(explored.map(c=>c.category)).size,completedCourses:completed.length,words:state.evidence.learnedWords,confirmedWords:state.evidence.learnedWords,curriculum:state.evidence};
 }
 function formalEvents(){
  const release=curriculum.active(),completed=new Map(),valid=new Set(catalog.courses.map(c=>c.id));
  const rows=store.db.prepare('SELECT user_id,course,min(at) started,max(at) updated FROM formal_steps WHERE release=? GROUP BY user_id,course').all(release);
  return rows.filter(r=>valid.has(r.course)).flatMap(r=>{
   if(!completed.has(r.user_id))completed.set(r.user_id,new Set(curriculum.state(r.user_id).evidence.completedCourses));
   const event=(type,at)=>({id:`formal:${release}:${r.user_id}:${r.course}:${type}`,user_id:r.user_id,course:r.course,stage:'',type,at,detail:{release,basis:'formal_steps',guided:true,independentMastery:false}});
   return [event('start',r.started),...(completed.get(r.user_id).has(r.course)?[event('finish',r.updated)]:[])];
  });
 }
 function users(){return auth.db.prepare('SELECT u.*,b.user_id IS NOT NULL AS blocked FROM users u LEFT JOIN blocked_users b ON b.user_id=u.id ORDER BY created DESC').all().map(row=>({...auth.profile(row),created:row.created,blocked:!!row.blocked}));}
 function range(url){const today=beijingDay(store.now()),from=url.searchParams.get('from')||today,to=url.searchParams.get('to')||today;
 if(![from,to].every(v=>/^\d{4}-\d{2}-\d{2}$/.test(v)&&!isNaN(Date.parse(v)))||from>to||Date.parse(to)-Date.parse(from)>366*86400000)error(400,'请选择一年以内的有效日期范围');return {from,to,start:Date.parse(from+'T00:00:00+08:00'),end:Date.parse(to+'T00:00:00+08:00')+86400000};}
 async function body(req,limit=200000){let size=0,chunks=[];for await(const c of req){size+=c.length;if(size>limit)error(413,'请求过大');chunks.push(c);}try{const value=JSON.parse(Buffer.concat(chunks).toString());if(!value||typeof value!=='object'||Array.isArray(value))throw Error();return value;}catch{error(400,'请求格式不正确');}}
 const handler=async(req,res,url)=>{
 const learning=url.pathname.startsWith('/api/auth/learning/'),internal=url.pathname.startsWith('/internal/management/v1/');
 if(!learning&&!internal)return false;
 try{
 if(internal){
  const remote=req.socket.remoteAddress;
  const supplied=req.headers.authorization||'';
  const expected='Bearer '+bridgeToken;
  if(!['127.0.0.1','::1','::ffff:127.0.0.1'].includes(remote)||!bridgeToken||Buffer.byteLength(supplied)!==Buffer.byteLength(expected)||!crypto.timingSafeEqual(Buffer.from(supplied),Buffer.from(expected)))error(403,'接口未授权');
 }else{
  const origin=`${secure?'https':'http'}://${req.headers.host}`;
  if(req.headers['sec-fetch-site']==='cross-site'||(req.headers.origin&&req.headers.origin!==origin)||(!['GET','HEAD'].includes(req.method)&&req.headers.origin!==origin))error(403,'请从本站发起请求');
 }
 catalog=curriculum.catalog();
 const input=['POST','PATCH'].includes(req.method)?await body(req,url.pathname.endsWith('/oral')?950000:200000):{};
 if(learning){
 const user=auth.current(learnerCookie(req));if(!user)error(401,'请登录后同步');
 const route=url.pathname.slice('/api/auth/learning/'.length);
 if(route.startsWith('pilot/')){const get=['pilot/catalog','pilot/summary','pilot/course','pilot/audio','pilot/phoneme'].includes(route);if(req.method!==(get?'GET':'POST'))error(405,'请求方法无效');json(res,200,await pilot.route(route,user.id,input,url));return true;}
 if(route==='curriculum'||route.startsWith('curriculum/')){const get=['curriculum','curriculum/state','curriculum/course','curriculum/media','curriculum/phoneme'].includes(route);if(req.method!==(get?'GET':'POST'))error(405,'请求方法无效');json(res,200,await curriculum.route(route,user.id,input,url));return true;}
 if(route==='summary'&&req.method==='GET'){
  json(res,200,formalSummary(user.id));return true;
 }
 if(route==='batch'&&req.method==='POST'){if(input.epoch!=='formal555-reset-v2')error(409,'学习资料已更新，请重新打开App');json(res,200,store.ingest(user.id,input,catalog));return true;}
 error(404,'接口不存在');
 }
 const route=url.pathname.slice('/internal/management/v1/'.length);
 if(route==='curriculum'&&req.method==='GET'){json(res,200,curriculum.catalog());return true;}
 if(route==='curriculum/media'&&req.method==='GET'){json(res,200,await curriculum.media(url.searchParams.get('course'),url.searchParams.get('release')||undefined,{preview:true}));return true;}
 if(route==='curriculum/audio'&&req.method==='GET'){const r=curriculum.runtime(url.searchParams.get('release')||undefined),id=url.searchParams.get('audio');const course=Object.entries(r.index.lessons).find(([,l])=>l.audioIds.includes(id))?.[0];if(!course)error(404,'正式音频不存在');const audio=curriculum.lesson(course,r.id).student.audio.find(a=>a.id===id);const [asset]=await curriculum.sign([{...audio,key:`courses/releases/${r.id}/runtime/${r.index.audio[id].path}`}]);json(res,200,{release:r.id,asset});return true;}
 if(route==='curriculum/course'&&req.method==='GET'){json(res,200,await curriculum.detail(url.searchParams.get('course'),url.searchParams.get('release')||undefined,{preview:true}));return true;}
 if(route==='curriculum/learner'&&req.method==='GET'){const id=url.searchParams.get('user');if(!users().some(u=>u.id===id))error(404,'用户不存在');json(res,200,{state:curriculum.state(id),trials:curriculum.trials(id)});return true;}
 if(!['GET','POST'].includes(req.method))error(405,'请求方法无效');
 if(route==='catalog'){json(res,200,{...catalog,releaseId:catalog.release,lexicon:catalog.lexicon||[]});return true;}
 if(route==='storage'){const formal=curriculum.status();json(res,200,{active:formal.active,formal,releases:[{id:formal.active,courseCount:555,files:formal.audioCount+555,bytes:formal.bytes,created:formal.created,active:true,published:true,label:'正式555课'}],storage:{courses:'private-cos',model:'private-cos',database:'server-sqlite',backup:null}});return true;}
 if(route==='overview'||route==='users'||route==='daily'||route==='events'){
 const {from,to,start,end}=range(url),all=users(),id=url.searchParams.get('user')||'',daily=store.daily(from,to,id),names=new Map(all.map(u=>[u.id,u]));
 const legacy=store.db.prepare('SELECT * FROM events WHERE at>=? AND at<? AND (?=\'\' OR user_id=?) ORDER BY at DESC LIMIT 10000').all(start,end,id,id).filter(e=>!['start','finish'].includes(e.type)&&catalog.courses.some(c=>c.id===e.course)).map(e=>({...e,detail:JSON.parse(e.detail)}));
 const events=[...legacy,...formalEvents().filter(e=>e.at>=start&&e.at<end&&(!id||e.user_id===id))].sort((a,b)=>b.at-a.at).slice(0,10000).map(e=>({...e,nickname:names.get(e.user_id)?.nickname||'未知用户'}));
 let rows;
 if(route==='overview'){
 json(res,200,{users:all.length,newUsers:all.filter(u=>u.created>=start&&u.created<end).length,activeUsers:new Set(daily.map(r=>r.userId)).size,foregroundMs:daily.reduce((n,r)=>n+r.foregroundMs,0),learningMs:daily.reduce((n,r)=>n+r.learningMs,0),starts:events.filter(e=>e.type==='start').length,finishes:events.filter(e=>e.type==='finish').length,published:catalog.courses.filter(c=>c.status==='published').length,trend:daily,started:Number(store.db.prepare('SELECT value FROM meta WHERE key=\'started\'').get().value),eventCount:events.length});return true;
 }
 if(route==='users')rows=all.map(u=>{const d=daily.filter(r=>r.userId===u.id),last=store.db.prepare('SELECT max(end) at FROM activity WHERE user_id=?').get(u.id).at;return {...u,foregroundMs:d.reduce((n,r)=>n+r.foregroundMs,0),learningMs:d.reduce((n,r)=>n+r.learningMs,0),last,summary:formalSummary(u.id)};});
 if(route==='daily')rows=daily.map(r=>({...r,nickname:names.get(r.userId)?.nickname||'未知用户',phoneMasked:names.get(r.userId)?.phoneMasked||'',attempts:events.filter(e=>e.user_id===r.userId&&beijingDay(e.at)===r.date&&['pass','correct','uncertain'].includes(e.type)).length}));
 if(route==='events')rows=events;
 if(['users','daily'].includes(route)){const sort=url.searchParams.get('sort');if(sort==='learning')rows.sort((a,b)=>b.learningMs-a.learningMs);if(sort==='foreground')rows.sort((a,b)=>b.foregroundMs-a.foregroundMs);}
 const q=(url.searchParams.get('q')||'').trim().toLowerCase();rows=rows.filter(r=>!q||JSON.stringify(r).toLowerCase().includes(q));
 if(url.searchParams.get('export')==='1'){
 json(res,200,{rows});return true;
 }
 const page=Math.max(1,Number(url.searchParams.get('page'))||1);json(res,200,{rows:rows.slice((page-1)*30,page*30),total:rows.length,page});return true;
 }
 if(route.startsWith('users/')){
 const id=route.slice(6),user=users().find(u=>u.id===id);if(!user)error(404,'用户不存在');
 if(req.method==='POST'){
 if(!['disable','enable','revoke'].includes(input.action))error(400,'操作无效');
 if(input.action==='disable')auth.db.prepare('INSERT OR IGNORE INTO blocked_users VALUES(?)').run(id);
 if(input.action==='enable')auth.db.prepare('DELETE FROM blocked_users WHERE user_id=?').run(id);
 if(input.action!=='enable')auth.db.prepare('DELETE FROM sessions WHERE user_id=?').run(id);
 json(res,200,{ok:true});return true;
 }
 const {from,to,start,end}=range(url);json(res,200,{user,summary:formalSummary(id),formalProgress:curriculum.state(id).progress,daily:store.daily(from,to,id),checkpoints:[],intervals:store.db.prepare('SELECT session_id,start,end,active,course FROM activity WHERE user_id=? AND end>? AND start<? ORDER BY start DESC LIMIT 500').all(id,start,end)});return true;
 }
 if(route==='system'){json(res,200,{release:catalog.release,database:'SQLite · WAL',speechConfigured:configured(),smsReady:auth.configured(),started:Number(store.db.prepare('SELECT value FROM meta WHERE key=\'started\'').get().value),backup:Number(store.db.prepare('SELECT value FROM meta WHERE key=\'backup\'').get()?.value)||null,backupError:store.backupError||null,backupScope:'正式业务数据备份',storage:{courses:'private-cos',model:'private-cos',runtime:curriculum.status()},courseCount:catalog.courses.filter(c=>c.status==='published').length});return true;}

 error(404,'接口不存在');
 }catch(e){json(res,e.status||503,{error:e.status?e.message:'学习服务暂时不可用'});}return true;
 };
 handler.maintenance=async()=>{
 try{await store.backup();await backup(auth.db,path.join(store.directory,'backups',`accounts-${beijingDay(store.now())}.sqlite`));
 fs.copyFileSync(path.join(auth.directory,'encryption.key'),path.join(store.directory,'backups','encryption.key'));
 store.db.prepare('INSERT OR REPLACE INTO meta VALUES(?,?)').run('backup',String(store.now()));store.backupError=null;
 }catch{store.backupError='最近备份未完整完成';}
 };
 return handler;
}
let handler;
export async function learningHttp(req,res,url){
 if(!url.pathname.startsWith('/api/auth/learning/')&&!url.pathname.startsWith('/internal/management/v1/'))return false;
 try{if(!handler){
 const file=path.join(projectRoot,'.secrets/management-bridge.json');
 const bridgeToken=fs.existsSync(file)?JSON.parse(fs.readFileSync(file,'utf8')).token:'';
 handler=createLearningHttp(new LearningStore(),getAuthStore(),{secure:process.env.AUTH_SECURE_COOKIE!=='0',bridgeToken});
 setInterval(()=>handler.maintenance(),86400000).unref();setTimeout(()=>handler.maintenance(),5000).unref();
 }return await handler(req,res,url);}catch{json(res,503,{error:'学习服务尚未准备好'});return true;}
}
