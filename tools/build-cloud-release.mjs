import fs from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {spawnSync} from 'node:child_process';
const root=fileURLToPath(new URL('../',import.meta.url));
const dest=path.join(root,'work/cloud-deploy');
await fs.mkdir(dest,{recursive:true});
const configFile=path.join(root,'.secrets/cloud-preview.json');
try{await fs.access(configFile);}catch{
 await fs.writeFile(configFile,JSON.stringify({origin:'https://49.233.179.83',accessMode:'public'},null,2));
}
// Explicit allowlist: no .secrets, source Blender files or diagnostic recordings.
// COS/STS backend packages are pure JS; ship the exact audited lockfile dependencies.
const r=spawnSync('tar',['-czf',path.join(dest,'release.tar.gz'),'-C',root,'build/web','server.mjs','services','package.json','package-lock.json','node_modules'],{stdio:'inherit'});
if(r.status!==0)throw Error('release archive failed');
console.log(JSON.stringify({archive:path.join(dest,'release.tar.gz'),bytes:(await fs.stat(path.join(dest,'release.tar.gz'))).size}));
