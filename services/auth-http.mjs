import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {DatabaseSync} from 'node:sqlite';
import {projectRoot} from './tencent-speech.mjs';
import {smsConfigured,sendLoginCode} from './tencent-sms.mjs';

const minute=60000,day=86400000;
const opaque=()=>crypto.randomBytes(32).toString('base64url');
const hash=s=>crypto.createHash('sha256').update(s).digest('hex');
export class AuthError extends Error {constructor(status,message,retryAfter=0){super(message);this.status=status;this.retryAfter=retryAfter;}}
function fail(status,message,retry=0){throw new AuthError(status,message,retry);}
export function normalizePhone(value){
  const n=String(value??'').replace(/[\s-]/g,'').replace(/^\+86/,'');
  if(!/^1[3-9]\d{9}$/.test(n))fail(400,'请输入正确的中国大陆手机号');
  return '+86'+n;
}
export function normalizeNickname(value){
  const n=typeof value==='string'?value.trim():'';
  if(!n||[...n].length>12||/[<>\p{C}]/u.test(n))fail(400,'昵称请填写 1–12 个可见字符');
  return n;
}
export class AuthStore {
  constructor({directory=path.join(projectRoot,'work/auth-private'),secret,send=sendLoginCode,configured=smsConfigured,now=Date.now}={}){
    fs.mkdirSync(directory,{recursive:true,mode:0o700});
    const keyFile=path.join(directory,'encryption.key');
    if(!secret){if(!fs.existsSync(keyFile))fs.writeFileSync(keyFile,crypto.randomBytes(32),{mode:0o600,flag:'wx'});secret=fs.readFileSync(keyFile);}
    if(secret.length!==32)throw new Error('Invalid auth encryption key');
    this.key=secret;this.send=send;this.configured=configured;this.now=now;
    this.db=new DatabaseSync(path.join(directory,'accounts.sqlite'));
    this.db.exec(`PRAGMA journal_mode=WAL; PRAGMA busy_timeout=5000;
      CREATE TABLE IF NOT EXISTS users(id TEXT PRIMARY KEY,phone_key TEXT UNIQUE NOT NULL,phone_cipher TEXT NOT NULL,nickname TEXT NOT NULL,created INTEGER NOT NULL);
      CREATE TABLE IF NOT EXISTS challenges(id TEXT PRIMARY KEY,phone_key TEXT NOT NULL,phone_cipher TEXT NOT NULL,code_hash TEXT NOT NULL,expires INTEGER NOT NULL,attempts INTEGER NOT NULL DEFAULT 0,ready INTEGER NOT NULL DEFAULT 0);
      CREATE TABLE IF NOT EXISTS tickets(token_hash TEXT PRIMARY KEY,phone_key TEXT NOT NULL,phone_cipher TEXT NOT NULL,expires INTEGER NOT NULL);
      CREATE TABLE IF NOT EXISTS sessions(token_hash TEXT PRIMARY KEY,user_id TEXT NOT NULL,expires INTEGER NOT NULL);
      CREATE TABLE IF NOT EXISTS hits(kind TEXT NOT NULL,subject TEXT NOT NULL,at INTEGER NOT NULL);
      CREATE INDEX IF NOT EXISTS hits_lookup ON hits(kind,subject,at);
    `);
    try{fs.chmodSync(path.join(directory,'accounts.sqlite'),0o600);}catch{}
  }
  digest(value){return crypto.createHmac('sha256',this.key).update(value).digest('hex');}
  encrypt(value){const iv=crypto.randomBytes(12),c=crypto.createCipheriv('aes-256-gcm',this.key,iv);return this._encrypt(c,iv,value);}
  _encrypt(c,iv,value){const bytes=Buffer.concat([c.update(value,'utf8'),c.final()]);return Buffer.concat([iv,c.getAuthTag(),bytes]).toString('base64');}
  decrypt(value){const b=Buffer.from(value,'base64'),d=crypto.createDecipheriv('aes-256-gcm',this.key,b.subarray(0,12));d.setAuthTag(b.subarray(12,28));return Buffer.concat([d.update(b.subarray(28)),d.final()]).toString();}
  cleanup(){const t=this.now();for(const table of ['challenges','tickets','sessions'])this.db.prepare(`DELETE FROM ${table} WHERE expires<=?`).run(t);this.db.prepare('DELETE FROM hits WHERE at<?').run(t-day);}
  count(kind,key,period){return this.db.prepare('SELECT count(*) AS n FROM hits WHERE kind=? AND subject=? AND at>?').get(kind,key,this.now()-period).n;}
  hit(kind,key){this.db.prepare('INSERT INTO hits VALUES(?,?,?)').run(kind,key,this.now());}
  async requestCode(phone,ip){
    phone=normalizePhone(phone);
    if(!this.configured())fail(503,'短信验证正在准备中，请先体验课程');
    this.cleanup();const pk=this.digest(phone),ik=this.digest(ip);
    if(this.count('phone',pk,minute))fail(429,'请稍后再获取验证码',60);
    if(this.count('phone',pk,60*minute)>=3||this.count('phone',pk,day)>=5||this.count('ip',ik,60*minute)>=10||this.count('ip',ik,day)>=30||this.count('global','all',day)>=100)fail(429,'获取次数较多，请稍后再试',3600);
    this.hit('phone',pk);this.hit('ip',ik);this.hit('global','all');
    const id=opaque(),code=String(crypto.randomInt(0,1000000)).padStart(6,'0');
    this.db.prepare('DELETE FROM challenges WHERE phone_key=?').run(pk);
    this.db.prepare('INSERT INTO challenges(id,phone_key,phone_cipher,code_hash,expires) VALUES(?,?,?,?,?)').run(id,pk,this.encrypt(phone),this.digest(id+':'+code),this.now()+5*minute);
    try{await this.send(phone,code);}catch{this.db.prepare('DELETE FROM challenges WHERE id=?').run(id);fail(503,'验证码未能发送，请稍后重试');}
    this.db.prepare('UPDATE challenges SET ready=1 WHERE id=?').run(id);
    return {challengeId:id,retryAfter:60,expiresIn:300};
  }
  profile(row){const phone=this.decrypt(row.phone_cipher);return {id:row.id,nickname:row.nickname,phoneMasked:phone.slice(3,6)+'****'+phone.slice(-4)};}
  createSession(user){const token=opaque();this.db.prepare('INSERT INTO sessions VALUES(?,?,?)').run(hash(token),user.id,this.now()+30*day);return {token,user:this.profile(user)};}
  verify({challengeId,code},ip){
    this.cleanup();const ik=this.digest(ip);if(this.count('verify',ik,15*minute)>=30)fail(429,'尝试次数较多，请稍后再试',900);this.hit('verify',ik);
    if(typeof challengeId!=='string'||typeof code!=='string'||!/^\d{6}$/.test(code))fail(400,'请输入 6 位短信验证码');
    const row=this.db.prepare('SELECT * FROM challenges WHERE id=?').get(challengeId);
    if(!row||!row.ready||row.attempts>=5)fail(400,'验证码已失效，请重新获取');
    this.db.prepare('UPDATE challenges SET attempts=attempts+1 WHERE id=?').run(challengeId);
    if(!crypto.timingSafeEqual(Buffer.from(row.code_hash,'hex'),Buffer.from(this.digest(challengeId+':'+code),'hex')))fail(400,'验证码不正确，请再试一次');
    this.db.exec('BEGIN IMMEDIATE');
    try{
      this.db.prepare('DELETE FROM challenges WHERE id=?').run(challengeId);
      const user=this.db.prepare('SELECT * FROM users WHERE phone_key=?').get(row.phone_key);
      let result;
      if(user)result=this.createSession(user);
      else {const ticket=opaque();this.db.prepare('INSERT INTO tickets VALUES(?,?,?,?)').run(hash(ticket),row.phone_key,row.phone_cipher,this.now()+5*minute);result={registrationToken:ticket};}
      this.db.exec('COMMIT');return result;
    }catch(e){this.db.exec('ROLLBACK');throw e;}
  }
  register(ticket,nickname){
    nickname=normalizeNickname(nickname);if(typeof ticket!=='string')fail(400,'请先验证手机号');
    this.cleanup();this.db.exec('BEGIN IMMEDIATE');
    try{
      const proof=this.db.prepare('SELECT * FROM tickets WHERE token_hash=?').get(hash(ticket));
      if(!proof)fail(400,'手机号验证已过期，请重新获取验证码');
      let user=this.db.prepare('SELECT * FROM users WHERE phone_key=?').get(proof.phone_key);
      if(!user){user={id:crypto.randomUUID(),nickname,phone_key:proof.phone_key,phone_cipher:proof.phone_cipher};this.db.prepare('INSERT INTO users VALUES(?,?,?,?,?)').run(user.id,user.phone_key,user.phone_cipher,nickname,this.now());}
      this.db.prepare('DELETE FROM tickets WHERE phone_key=?').run(proof.phone_key);
      const result=this.createSession(user);this.db.exec('COMMIT');return result;
    }catch(e){this.db.exec('ROLLBACK');throw e;}
  }
  current(token){if(!token)return null;const row=this.db.prepare('SELECT u.* FROM sessions s JOIN users u ON u.id=s.user_id WHERE s.token_hash=? AND s.expires>?').get(hash(token),this.now());return row?this.profile(row):null;}
  logout(token){if(token)this.db.prepare('DELETE FROM sessions WHERE token_hash=?').run(hash(token));}
  rename(token,nickname){const user=this.current(token);if(!user)fail(401,'请重新登录');nickname=normalizeNickname(nickname);this.db.prepare('UPDATE users SET nickname=? WHERE id=?').run(nickname,user.id);return {...user,nickname};}
  close(){this.db.close();}
}
function cookie(req){return /(?:^|;\s*)scene_session=([A-Za-z0-9_-]{43})(?:;|$)/.exec(req.headers.cookie||'')?.[1];}
function reply(res,status,data,headers={}){res.writeHead(status,{'Content-Type':'application/json; charset=utf-8','Cache-Control':'no-store',...headers}).end(JSON.stringify(data));}
export function createAuthHttp(store,{secure=true}={}){
  return async(req,res,url)=>{
    if(!url.pathname.startsWith('/api/auth/'))return false;
    const host=req.headers.host,scheme=secure?'https':'http';
    if(!host||req.headers['sec-fetch-site']==='cross-site'||(req.headers.origin&&req.headers.origin!==`${scheme}://${host}`)||(['POST','PATCH'].includes(req.method)&&req.headers.origin!==`${scheme}://${host}`)){
      reply(res,403,{error:'请从本站页面发起请求'});return true;
    }
    const token=cookie(req),sessionCookie=t=>`scene_session=${t}; HttpOnly; SameSite=Lax; Path=/api/auth; Max-Age=${t?2592000:0}${secure?'; Secure':''}`;
    try{
      const route=url.pathname.slice('/api/auth/'.length);
      if(req.method==='GET'&&route==='status'){reply(res,200,{smsReady:store.configured()});return true;}
      if(req.method==='GET'&&route==='me'){reply(res,200,{user:store.current(token)});return true;}
      if(!['POST','PATCH'].includes(req.method)||!req.headers['content-type']?.startsWith('application/json'))fail(400,'请求格式不正确');
      const chunks=[];let size=0;for await(const part of req){size+=part.length;if(size>4096)fail(413,'请求内容过大');chunks.push(part);}
      const body=Buffer.concat(chunks).toString('utf8');
      let input;try{input=JSON.parse(body);}catch{fail(400,'请求格式不正确');}if(!input||typeof input!=='object'||Array.isArray(input))fail(400,'请求格式不正确');
      // X-Real-IP is overwritten by our loopback-only reverse proxy, never trusted directly from an internet socket.
      const loopback=['127.0.0.1','::1','::ffff:127.0.0.1'].includes(req.socket.remoteAddress);
      const ip=loopback?(req.headers['x-real-ip']||req.socket.remoteAddress):req.socket.remoteAddress;
      let result;
      if(req.method==='POST'&&route==='code')result=await store.requestCode(input.phone,String(ip));
      else if(req.method==='POST'&&route==='verify')result=store.verify(input,String(ip));
      else if(req.method==='POST'&&route==='register')result=store.register(input.registrationToken,input.nickname);
      else if(req.method==='PATCH'&&route==='me')result={user:store.rename(token,input.nickname)};
      else if(req.method==='POST'&&route==='logout'){store.logout(token);reply(res,200,{ok:true},{'Set-Cookie':sessionCookie('')});return true;}
      else fail(404,'接口不存在');
      if(result.token){store.logout(token);const newToken=result.token;delete result.token;reply(res,200,result,{'Set-Cookie':sessionCookie(newToken)});}else reply(res,200,result);
    }catch(e){reply(res,e instanceof AuthError?e.status:500,{error:e instanceof AuthError?e.message:'暂时无法完成，请稍后重试',...(e.retryAfter?{retryAfter:e.retryAfter}:{})});}
    return true;
  };
}
let handler;
export async function authHttp(req,res,url){
  if(!url.pathname.startsWith('/api/auth/'))return false;
  try{handler??=createAuthHttp(new AuthStore(),{secure:process.env.AUTH_SECURE_COOKIE!=='0'});}catch{reply(res,503,{error:'账号服务暂时不可用，请稍后重试'});return true;}
  return handler(req,res,url);
}
