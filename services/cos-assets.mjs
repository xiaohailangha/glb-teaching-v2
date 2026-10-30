import fs from 'node:fs';
import COS from 'cos-nodejs-sdk-v5';
import tencentcloud from 'tencentcloud-sdk-nodejs-sts';
import {credentials} from './tencent-speech.mjs';
import {trustedRequest} from './speech-http.mjs';
const configFile=new URL('../.secrets/cos-assets.json',import.meta.url);
let cached=null,pending=null;
export function assetReadPolicy(config){
 return {version:'2.0',statement:[{effect:'allow',action:['name/cos:GetObject'],resource:[`qcs::cos:${config.region}:uid/${config.appId}:${config.bucket}/${config.prefix}/*`]}]};
}
async function issueToken(config){
 const c=credentials();
 const client=new tencentcloud.sts.v20180813.Client({credential:{secretId:c.secretId,secretKey:c.secretKey},region:config.region,profile:{httpProfile:{reqTimeout:15}}});
 return client.GetFederationToken({Name:'glb-model-read',DurationSeconds:3600,Policy:JSON.stringify(assetReadPolicy(config))});
}
export async function createModelManifest(config,{tokenProvider=issueToken}={}){
 const token=await tokenProvider(config),c=token.Credentials;
 const cos=new COS({SecretId:c.TmpSecretId,SecretKey:c.TmpSecretKey,SecurityToken:c.Token,Protocol:'https:'});
 const parts=await Promise.all(config.parts.map(part=>new Promise((resolve,reject)=>cos.getObjectUrl({Bucket:config.bucket,Region:config.region,Key:part.key,Sign:true,Expires:3300,Protocol:'https:'},(e,r)=>e?reject(e):resolve({url:r.Url,size:part.size,sha256:part.sha256})))));
 return {version:1,revision:config.revision,size:config.size,chunkSize:config.chunkSize,expiresAt:Date.now()+3300000,parts};
}
export async function modelManifest(){
 if(process.env.COS_ASSETS_ENABLED!=='true'||!fs.existsSync(configFile))return null;
 if(cached&&cached.expiresAt>Date.now()+300000)return cached;
 if(pending)return pending;
 pending=(async()=>{const config=JSON.parse(fs.readFileSync(configFile,'utf8'));return cached=await createModelManifest(config);})();
 try{return await pending;}finally{pending=null;}
}
export async function assetHttp(req,res,url){
 if(url.pathname!=='/api/assets/model-manifest')return false;
 const reply=(status,data)=>res.writeHead(status,{'Content-Type':'application/json; charset=utf-8','Cache-Control':'private, no-store'}).end(JSON.stringify(data));
 if(!trustedRequest(req)){reply(403,{error:'Access denied'});return true;}
 if(req.method!=='GET'){reply(405,{error:'GET required'});return true;}
 try{const data=await modelManifest();reply(data?200:404,data||{available:false});}
 catch{reply(503,{error:'模型存储暂时不可用，将使用服务器资源'});}
 return true;
}
