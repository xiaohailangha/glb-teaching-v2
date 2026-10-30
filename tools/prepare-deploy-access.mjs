import fs from 'node:fs';
import {spawnSync} from 'node:child_process';
import {api} from './tencent-deploy-api.mjs';
const folder=new URL('../.secrets/',import.meta.url);
const key=new URL('lighthouse-deploy',folder);
const {fileURLToPath}=await import('node:url');
if(!fs.existsSync(key)){
 const r=spawnSync('ssh-keygen',['-t','ed25519','-f',fileURLToPath(key),'-N','','-C','glb-temporary-deploy-20261030'],{encoding:'utf8'});
 if(r.status!==0)throw Error(r.stderr||'key generation failed');
}
const pub=fs.readFileSync(fileURLToPath(key)+'.pub','utf8').trim();
const script=`set -eu
install -d -m 700 /root/.ssh
touch /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys
grep -q 'glb-temporary-deploy-20261030' /root/.ssh/authorized_keys || printf '%s\\n' 'no-agent-forwarding,no-port-forwarding,no-X11-forwarding ${pub}' >> /root/.ssh/authorized_keys
cat /etc/ssh/ssh_host_ed25519_key.pub
`;
console.log(JSON.stringify(await api('tat','RunCommand',{InstanceIds:['lhins-52h0i09a'],CommandName:'glb-temporary-upload-access',Content:Buffer.from(script).toString('base64'),CommandType:'SHELL',SaveCommand:false,Timeout:60,Username:'root'})));
