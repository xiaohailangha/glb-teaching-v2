import fs from 'node:fs';
import path from 'node:path';
import {execFileSync} from 'node:child_process';
const hooks=execFileSync('git',['rev-parse','--git-path','hooks'],{encoding:'utf8'}).trim();
const target=path.join(hooks,'pre-commit'),marker='glb-project-secret-check';
if(fs.existsSync(target)&&!fs.readFileSync(target,'utf8').includes(marker))throw Error('An existing pre-commit hook needs manual integration; it was left unchanged.');
fs.mkdirSync(hooks,{recursive:true});
// Editors may have been started before fnm added Node to the shell's PATH.
// Resolve the installation, not fnm's short-lived multishell junction.
const nodePath=fs.realpathSync(process.execPath).replaceAll('\\','/');
const shellQuote=value=>"'"+value.replaceAll("'","'\\''")+"'";
fs.writeFileSync(target,`#!/bin/sh
# ${marker}
if command -v node >/dev/null 2>&1; then
  exec node tools/check-staged-secrets.mjs
fi
node_fallback=${shellQuote(nodePath)}
if [ -x "$node_fallback" ]; then
  exec "$node_fallback" tools/check-staged-secrets.mjs
fi
printf '%s\\n' 'Node is unavailable. Run node tools/install-git-checks.mjs from a Node-enabled terminal, then retry the commit.' >&2
exit 1
`,{mode:0o755});
console.log('Project staged-secret check installed. Git LFS pre-push hook preserved.');
