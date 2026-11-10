import fs from 'node:fs';
import path from 'node:path';
import {getAuthStore,learnerCookie} from './auth-http.mjs';
import {projectRoot} from './storage-paths.mjs';

export async function contentHttp(req,res,url){
 if(url.pathname!=='/api/auth/content')return false;
 const reply=(status,data)=>res.writeHead(status,{'Content-Type':'application/json','Cache-Control':'private, no-store'}).end(JSON.stringify(data));
 try{
  if(req.method!=='GET'){reply(405,{error:'请求方法无效'});return true;}
  const origin=`${process.env.AUTH_SECURE_COOKIE==='0'?'http':'https'}://${req.headers.host}`;
  if(req.headers['sec-fetch-site']==='cross-site'||(req.headers.origin&&req.headers.origin!==origin)){reply(403,{error:'请从本站访问课程'});return true;}
  if(url.searchParams.has('preview')){reply(404,{error:'接口不存在'});return true;}
  if(!getAuthStore().current(learnerCookie(req))){reply(401,{error:'请登录后加载课程'});return true;}
  const directory=path.join(projectRoot,'data/curriculum/cloud-runtime');
  const release=url.searchParams.get('release')||JSON.parse(fs.readFileSync(path.join(directory,'current.json'),'utf8')).release;
  if(!/^[a-f0-9]{64}$/.test(release))throw Error('Invalid release');
  const bytes=fs.readFileSync(path.join(directory,'releases',release,'index.json'));
  if((await import('node:crypto')).createHash('sha256').update(bytes).digest('hex')!==release)throw Error('Invalid index');
  const index=JSON.parse(bytes);
  reply(200,{schema:1,id:release,formal:true,catalog:index.catalog,assets:[],expiresAt:Date.now()+900000});
 }catch(error){reply(error.status||503,{error:error.status?error.message:'课程资源暂时不可用，请重试'});}
 return true;
}
