import fs from 'node:fs';
import COS from 'cos-nodejs-sdk-v5';
import tencentcloud from 'tencentcloud-sdk-nodejs-sts';
import {credentials} from './tencent-speech.mjs';
import {trustedRequest} from './speech-http.mjs';
const configs={model:new URL('../.secrets/cos-assets.json',import.meta.url),scene:new URL('../.secrets/cos-scene-assets.json',import.meta.url)};
const cached=new Map(),pending=new Map();
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
export async function modelManifest(kind='model'){
 const configFile=configs[kind];
 if(!configFile||process.env.COS_ASSETS_ENABLED!=='true'||!fs.existsSync(configFile))return null;
 const hit=cached.get(kind);if(hit&&hit.expiresAt>Date.now()+300000)return hit;
 if(pending.has(kind))return pending.get(kind);
 const request=(async()=>{const config=JSON.parse(fs.readFileSync(configFile,'utf8'));const manifest=await createModelManifest(config);cached.set(kind,manifest);return manifest;})();
 pending.set(kind,request);
 try{return await request;}finally{pending.delete(kind);}
}
export async function assetHttp(req,res,url){
 const kind={'/api/assets/model-manifest':'model','/api/assets/scene-manifest':'scene'}[url.pathname];
 if(!kind)return false;
 const reply=(status,data)=>res.writeHead(status,{'Content-Type':'application/json; charset=utf-8','Cache-Control':'private, no-store'}).end(JSON.stringify(data));
 if(!trustedRequest(req)){reply(403,{error:'Access denied'});return true;}
 if(req.method!=='GET'){reply(405,{error:'GET required'});return true;}
 try{const data=await modelManifest(kind);reply(data?200:404,data||{available:false});}
 catch{reply(503,{error:'模型存储暂时不可用，将使用服务器资源'});}
 return true;
}
