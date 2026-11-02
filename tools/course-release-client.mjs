import assert from 'node:assert/strict';
import {remote} from './remote.mjs';
export const origin='https://49.233.179.83';
let manifest;
export async function courseManifest(){
 if(!manifest){const token=(await remote(`cd /opt/glb-teaching && /opt/glb-runtime/node/bin/node --input-type=module <<'JS'
import fs from 'node:fs';import {previewToken} from './services/content-store.mjs';console.log(previewToken(JSON.parse(fs.readFileSync('.secrets/management-bridge.json','utf8')).token));
JS`,'snow-resource-verification')).trim();const url=new URL('/api/auth/content',origin);url.searchParams.set('preview',token);const response=await fetch(url,{signal:AbortSignal.timeout(30000)});assert.equal(response.status,200,'Authorized course manifest');manifest=await response.json();}
 return manifest;
}
export async function courseGet(path){const m=await courseManifest(),key=path.replace(/^\/scene\/assets\//,'');const asset=m.assets.find(a=>a.path===key);assert.ok(asset,'Published asset exists: '+key);return fetch(asset.url,{signal:AbortSignal.timeout(30000)});}
