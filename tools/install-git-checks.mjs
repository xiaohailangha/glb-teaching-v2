import fs from 'node:fs';
import path from 'node:path';
import {execFileSync} from 'node:child_process';
const hooks=execFileSync('git',['rev-parse','--git-path','hooks'],{encoding:'utf8'}).trim();
const target=path.join(hooks,'pre-commit'),marker='glb-project-secret-check';
if(fs.existsSync(target)&&!fs.readFileSync(target,'utf8').includes(marker))throw Error('An existing pre-commit hook needs manual integration; it was left unchanged.');
fs.mkdirSync(hooks,{recursive:true});
fs.writeFileSync(target,`#!/bin/sh\n# ${marker}\nexec node tools/check-staged-secrets.mjs\n`,{mode:0o755});
console.log('Project staged-secret check installed. Git LFS pre-push hook preserved.');
