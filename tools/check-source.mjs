import fs from 'node:fs';
import path from 'node:path';
import {spawnSync} from 'node:child_process';

// Check all maintained server and tooling modules, not a stale hand-picked list.
const files=fs.existsSync('server.mjs')?['server.mjs']:[];
for(const directory of ['services','tools','test']) {
  for(const name of (fs.existsSync(directory)?fs.readdirSync(directory):[])) {
    if(/\.(mjs|js)$/.test(name))files.push(path.join(directory,name));
  }
}
for(const file of files) {
  const result=spawnSync(process.execPath,['--check',file],{stdio:'inherit'});
  if(result.status!==0)process.exit(result.status??1);
}
console.log(`Syntax checked ${files.length} JavaScript modules.`);
