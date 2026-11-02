import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import COS from 'cos-nodejs-sdk-v5';
import {contentDirectory,projectRoot,dataRoot,cacheRoot} from './storage-paths.mjs';
import {credentials} from './tencent-speech.mjs';

const hash=v=>crypto.createHash('sha256').update(v).digest('hex');
const fail=(status,message)=>{throw Object.assign(Error(message),{status});};
export function validateRelease(value){
 if(value?.schema!==1||!/^[a-f0-9]{64}$/.test(value.id)||!Array.isArray(value.catalog?.courses)||!Array.isArray(value.assets))fail(400,'课程版本格式无效');
 const published=value.catalog.courses.filter(c=>c.status==='published');
 if(!published.length||new Set(published.map(c=>c.id)).size!==published.length)fail(400,'课程目录为空或重复');
 const seen=new Set();
 for(const a of value.assets){
  if(!/^assets\/avatar\/(audio|images|courses)\/[a-zA-Z0-9_.-]+\.(json|wav|svg|txt)$/.test(a.path)||seen.has(a.path)||!Number.isSafeInteger(a.size)||a.size<0||a.size>20000000||!/^[a-f0-9]{64}$/.test(a.sha256)||a.key!==`courses/releases/${value.id}/${a.path}`)fail(400,'课程资源清单无效');
  seen.add(a.path);
 }
 for(const c of value.catalog.courses.filter(c=>c.status==='published'))if(!seen.has(`assets/avatar/courses/${c.asset}.json`))fail(400,'缺少课程内容');
 const digest=hash(JSON.stringify({catalog:value.catalog,assets:value.assets.map(({path,size,sha256})=>({path,size,sha256}))}));
 if(digest!==value.id)fail(400,'课程版本校验失败');
 return value;
}
function atomic(file,value){fs.mkdirSync(path.dirname(file),{recursive:true,mode:0o700});const tmp=file+'.tmp-'+crypto.randomUUID();fs.writeFileSync(tmp,JSON.stringify(value,null,2),{mode:0o600});fs.renameSync(tmp,file);}
export class ContentStore{
 constructor({directory=contentDirectory,sign,now=Date.now}={}){this.directory=directory;this.now=now;this.sign=sign||signAssets;this.cache=new Map();}
 state(){try{return JSON.parse(fs.readFileSync(path.join(this.directory,'current.json'),'utf8'));}catch(e){if(e.code!=='ENOENT')throw e;return {active:null,published:[]};}}
 release(id=this.state().active){if(!/^[a-f0-9]{64}$/.test(id||''))fail(503,'课程版本尚未发布');return validateRelease(JSON.parse(fs.readFileSync(path.join(this.directory,'releases',id+'.json'),'utf8')));}
 stage(release){validateRelease(release);const file=path.join(this.directory,'releases',release.id+'.json');if(fs.existsSync(file)){this.release(release.id);return;}atomic(file,release);}
 activate(id,expected){const state=this.state();if(state.active!==expected)fail(409,'线上版本已变化，请刷新后重试');this.release(id);const next={active:id,published:[...new Set([...state.published,id])],updated:this.now(),previous:state.active};atomic(path.join(this.directory,'current.json'),next);this.cache.clear();return this.status();}
 catalog(){return this.release().catalog;}
 async manifest(id=this.state().active){
  if(!this.state().published.includes(id))fail(404,'课程版本未发布');
  const hit=this.cache.get(id);if(hit&&hit.expiresAt>this.now()+300000)return hit;
  const release=this.release(id),assets=await this.sign(release);
  const result={schema:1,id,catalog:release.catalog,assets,expiresAt:this.now()+3300000};this.cache.set(id,result);return result;
 }
 async managementCatalog(){
  const m=await this.manifest(),byPath=new Map(m.assets.map(a=>[a.path,a.url]));
  return JSON.parse(JSON.stringify({...m.catalog,releaseId:m.id,resourcesExpireAt:m.expiresAt}),(key,value)=>typeof value==='string'&&value.startsWith('/scene/assets/assets/avatar/')?(byPath.get(value.slice('/scene/assets/'.length))||null):value);
 }
 status(){
  const state=this.state();let releases=[];try{releases=fs.readdirSync(path.join(this.directory,'releases')).filter(n=>/^[a-f0-9]{64}\.json$/.test(n)).map(n=>{const r=this.release(n.slice(0,-5));return {id:r.id,created:r.created,label:r.catalog.release,courseCount:r.catalog.courses.filter(c=>c.status==='published').length,files:r.assets.length,bytes:r.assets.reduce((n,a)=>n+a.size,0),active:r.id===state.active,published:state.published.includes(r.id)};}).sort((a,b)=>b.created-a.created);}catch(e){if(e.code!=='ENOENT')throw e;}
  let backup=null;try{backup=JSON.parse(fs.readFileSync(path.join(dataRoot,'backup-status.json'),'utf8'));}catch{}
  return {active:state.active,updated:state.updated||null,releases,storage:{courses:'private-cos',model:'private-cos',database:'server-sqlite',dataRoot,cacheRoot,backup},policy:{recordings:'transient',releaseFiles:'immutable',backupRetentionDays:30}};
 }
}
async function signAssets(release){
 const config=JSON.parse(fs.readFileSync(path.join(projectRoot,'.secrets/cos-scene-assets.json'),'utf8')),c=credentials();
 const cos=new COS({SecretId:c.secretId,SecretKey:c.secretKey,Protocol:'https:'});
 return Promise.all(release.assets.map(a=>new Promise((resolve,reject)=>cos.getObjectUrl({Bucket:config.bucket,Region:config.region,Key:a.key,Sign:true,Expires:3300,Protocol:'https:'},(error,result)=>error?reject(error):resolve({...a,url:result.Url})))));
}
let singleton;
export function getContentStore(){return singleton??=new ContentStore();}
export function previewToken(secret,now=Date.now()){const body=Buffer.from(JSON.stringify({expires:now+300000,nonce:crypto.randomUUID()})).toString('base64url');return body+'.'+crypto.createHmac('sha256',secret).update(body).digest('base64url');}
export function validPreview(token,secret,now=Date.now()){
 try{if(!secret||typeof token!=='string'||token.length>500)return false;const [body,sig]=token.split('.'),expected=crypto.createHmac('sha256',secret).update(body).digest();const actual=Buffer.from(sig,'base64url');const value=JSON.parse(Buffer.from(body,'base64url'));return actual.length===expected.length&&crypto.timingSafeEqual(actual,expected)&&value.expires>now&&value.expires<=now+300000;}catch{return false;}
}
