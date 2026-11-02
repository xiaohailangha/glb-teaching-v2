import fs from 'node:fs';
import path from 'node:path';
import {getAuthStore,learnerCookie} from './auth-http.mjs';
import {getContentStore,validPreview} from './content-store.mjs';
import {projectRoot} from './storage-paths.mjs';

export async function contentHttp(req,res,url){
 if(url.pathname!=='/api/auth/content')return false;
 const reply=(status,data)=>res.writeHead(status,{'Content-Type':'application/json','Cache-Control':'private, no-store'}).end(JSON.stringify(data));
 try{
  if(req.method!=='GET'){reply(405,{error:'请求方法无效'});return true;}
  const origin=`${process.env.AUTH_SECURE_COOKIE==='0'?'http':'https'}://${req.headers.host}`;
  if(req.headers['sec-fetch-site']==='cross-site'||(req.headers.origin&&req.headers.origin!==origin)){reply(403,{error:'请从本站访问课程'});return true;}
  let preview=false;if(url.searchParams.has('preview')){const bridge=JSON.parse(fs.readFileSync(path.join(projectRoot,'.secrets/management-bridge.json'),'utf8'));preview=validPreview(url.searchParams.get('preview'),bridge.token);}
  if(!preview&&!getAuthStore().current(learnerCookie(req))){reply(401,{error:'请登录后加载课程'});return true;}
  const store=getContentStore();reply(200,await store.manifest(url.searchParams.get('release')||store.state().active));
 }catch(error){reply(error.status||503,{error:error.status?error.message:'课程资源暂时不可用，请重试'});}
 return true;
}
