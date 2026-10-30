// Isolated /scene/ release on the already authorized Tencent preview host.
// The original Three.js page and its model remain in place.
import fs from 'node:fs/promises';
import {spawn} from 'node:child_process';
import {api} from './tencent-deploy-api.mjs';

const instance='lhins-52h0i09a',host='49.233.179.83',label='glb-temporary-deploy-20261030';
async function run(source,name){
 const request=await api('tat','RunCommand',{InstanceIds:[instance],CommandName:name,CommandType:'SHELL',Content:Buffer.from(source).toString('base64'),SaveCommand:false,Timeout:120,Username:'root'});
 for(let i=0;i<55;i++){
  await new Promise(resolve=>setTimeout(resolve,2000));
  const result=await api('tat','DescribeInvocationTasks',{Filters:[{Name:'invocation-id',Values:[request.InvocationId]}],HideOutput:false});
  const task=result.InvocationTaskSet?.[0];if(!task)continue;
  if(task.TaskStatus==='SUCCESS')return Buffer.from(task.TaskResult?.Output||'','base64').toString();
  if(['FAILED','TIMEOUT','CANCELLED'].includes(task.TaskStatus))throw Error(`${name}: ${task.TaskStatus}\n${Buffer.from(task.TaskResult?.Output||'','base64').toString()}`);
 }
 throw Error(name+': remote completion unconfirmed');
}
function command(program,args){return new Promise((resolve,reject)=>{
 const child=spawn(program,args,{stdio:['ignore','pipe','pipe']});let error='';
 child.stderr.on('data',data=>{error+=data;});
 child.on('error',reject);child.on('exit',code=>code===0?resolve():reject(Error(program+': '+error)));
});}
await fs.access('scene-preview/build/web/main.dart.js');
await fs.access('.secrets/cos-scene-assets.json');
await command('tar',['-czf','work/cloud-deploy/scene-preview.tar.gz','-C','scene-preview/build/web','.']);
console.log('Scene release archive prepared.');
const publicKey=(await fs.readFile('.secrets/lighthouse-deploy.pub','utf8')).trim();
const cleanup=`set -eu
test "$(hostname)" = VM-0-11-ubuntu
python3 - <<'PY'
from pathlib import Path
p=Path('/root/.ssh/authorized_keys')
p.write_text('\\n'.join(line for line in p.read_text().splitlines() if '${label}' not in line)+'\\n')
p.chmod(0o600)
print('Temporary project upload authorization removed.')
PY
`;
try{
 console.log(await run(`set -eu
test "$(hostname)" = VM-0-11-ubuntu
test -f /opt/glb-teaching/server.mjs
systemctl is-active --quiet glb-teaching
systemctl is-active --quiet nginx
test "$(df --output=avail -B1 /opt | tail -1)" -gt 1000000000
install -d -m 700 /root/.ssh
touch /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys
grep -q '${label}' /root/.ssh/authorized_keys || printf '%s\\n' 'no-agent-forwarding,no-port-forwarding,no-X11-forwarding ${publicKey}' >> /root/.ssh/authorized_keys
echo SCENE_UPLOAD_READY
`,'glb-scene-upload-access'));
 const ssh=['-i','.secrets/lighthouse-deploy','-o','UserKnownHostsFile=.secrets/lighthouse-known-hosts','-o','StrictHostKeyChecking=yes','-o','IdentitiesOnly=yes'];
 for(const [source,target]of [
  ['work/cloud-deploy/scene-preview.tar.gz','glb-scene-preview.tar.gz'],
  ['services/cos-assets.mjs','glb-scene-cos-assets.mjs'],
  ['services/speech-http.mjs','glb-scene-speech-http.mjs'],
  ['services/live-recognition.mjs','glb-scene-live-recognition.mjs'],
  ['.secrets/cos-scene-assets.json','glb-scene-assets.json'],
 ])await command('scp',[...ssh,source,`root@${host}:/root/${target}`]);
 console.log('Scene release uploaded.');
 console.log(await run(`#!/bin/bash
set -euo pipefail
test "$(hostname)" = VM-0-11-ubuntu
backup=/opt/glb-backups/before-scene-$(date -u +%Y%m%dT%H%M%SZ)
install -d -m 700 "$backup"
cp /etc/nginx/sites-available/glb-teaching "$backup/nginx.conf"
cp /opt/glb-teaching/services/cos-assets.mjs "$backup/cos-assets.mjs"
cp /opt/glb-teaching/services/speech-http.mjs "$backup/speech-http.mjs"
if test -f /opt/glb-teaching/services/live-recognition.mjs; then cp /opt/glb-teaching/services/live-recognition.mjs "$backup/live-recognition.mjs"; fi
if test -f /opt/glb-teaching/.secrets/cos-scene-assets.json; then cp /opt/glb-teaching/.secrets/cos-scene-assets.json "$backup/scene-config.json"; fi
stage=$(mktemp -d /opt/glb-scene-stage-XXXXXX)
python3 - "$stage" <<'PY'
import sys,pathlib,tarfile,gzip,shutil
stage=pathlib.Path(sys.argv[1])
with tarfile.open('/root/glb-scene-preview.tar.gz') as archive:
    for member in archive.getmembers():
        path=pathlib.PurePosixPath(member.name)
        assert not path.is_absolute() and '..' not in path.parts
        assert member.isfile() or member.isdir()
    archive.extractall(stage,filter='data')
assert (stage/'index.html').is_file() and (stage/'main.dart.js').is_file()
for file in stage.rglob('*'):
    if file.is_file() and file.suffix in ('.js','.json','.wasm','.fsceneb','.ttf','.css','.html') and file.stat().st_size>1024:
        with file.open('rb') as src,gzip.open(str(file)+'.gz','wb',compresslevel=5) as dst: shutil.copyfileobj(src,dst)
        pathlib.Path(str(file)+'.gz').chmod(0o644)
    file.chmod(0o755 if file.is_dir() else 0o644)
stage.chmod(0o755)
PY
scene_installed=0
rollback(){
 trap - ERR
 cp "$backup/nginx.conf" /etc/nginx/sites-available/glb-teaching
 cp "$backup/cos-assets.mjs" /opt/glb-teaching/services/cos-assets.mjs
 cp "$backup/speech-http.mjs" /opt/glb-teaching/services/speech-http.mjs
 if test -f "$backup/live-recognition.mjs"; then cp "$backup/live-recognition.mjs" /opt/glb-teaching/services/live-recognition.mjs; fi
 if test -f "$backup/scene-config.json"; then install -o glbapp -g glbapp -m 600 "$backup/scene-config.json" /opt/glb-teaching/.secrets/cos-scene-assets.json; fi
 if test "$scene_installed" = 1 && test -d /opt/glb-teaching/build/web/scene; then mv /opt/glb-teaching/build/web/scene "$stage.failed"; fi
 if test -d "$backup/scene"; then mv "$backup/scene" /opt/glb-teaching/build/web/scene; fi
 systemctl restart glb-teaching
 nginx -t && systemctl reload nginx
 echo SCENE_RELEASE_ROLLED_BACK >&2
}
trap rollback ERR
backend_changed=0
if ! cmp -s /root/glb-scene-speech-http.mjs /opt/glb-teaching/services/speech-http.mjs || ! cmp -s /root/glb-scene-live-recognition.mjs /opt/glb-teaching/services/live-recognition.mjs; then backend_changed=1; fi
/opt/glb-runtime/node/bin/node --check /root/glb-scene-speech-http.mjs
/opt/glb-runtime/node/bin/node --check /root/glb-scene-live-recognition.mjs
if ! cmp -s /root/glb-scene-cos-assets.mjs /opt/glb-teaching/services/cos-assets.mjs || ! cmp -s /root/glb-scene-assets.json /opt/glb-teaching/.secrets/cos-scene-assets.json; then backend_changed=1; fi
if test -d /opt/glb-teaching/build/web/scene; then mv /opt/glb-teaching/build/web/scene "$backup/scene"; fi
mv "$stage" /opt/glb-teaching/build/web/scene
scene_installed=1
install -o glbapp -g glbapp -m 644 /root/glb-scene-speech-http.mjs /opt/glb-teaching/services/speech-http.mjs
install -o glbapp -g glbapp -m 644 /root/glb-scene-live-recognition.mjs /opt/glb-teaching/services/live-recognition.mjs
install -o glbapp -g glbapp -m 644 /root/glb-scene-cos-assets.mjs /opt/glb-teaching/services/cos-assets.mjs
install -o glbapp -g glbapp -m 600 /root/glb-scene-assets.json /opt/glb-teaching/.secrets/cos-scene-assets.json
python3 - <<'PY'
from pathlib import Path
p=Path('/etc/nginx/sites-available/glb-teaching')
s=p.read_text()
assert 'server_name ${host}' in s and 'root /opt/glb-teaching/build/web;' in s
if 'location = /api/assets/scene-manifest' not in s:
    marker='  location = /api/assets/model-manifest {'
    assert marker in s
    block='''  location = /api/assets/scene-manifest {
    proxy_pass http://127.0.0.1:5296;
    proxy_set_header Host 127.0.0.1:5296;
    proxy_set_header Origin http://127.0.0.1:5296;
    proxy_set_header Sec-Fetch-Site same-origin;
    proxy_set_header Authorization "";
    proxy_set_header Cookie "";
    proxy_read_timeout 25s;
    add_header Cache-Control "private, no-store" always;
  }
'''
    p.write_text(s.replace(marker,block+marker))
PY
nginx -t
if test "$backend_changed" = 1; then systemctl restart glb-teaching; fi
curl --retry 5 --retry-connrefused --retry-delay 1 -fsS -H 'Host: 127.0.0.1:5296' http://127.0.0.1:5296/api/speech/status >/dev/null
curl --retry 3 --retry-delay 1 -fsS -H 'Host: 127.0.0.1:5296' http://127.0.0.1:5296/api/assets/scene-manifest >/dev/null
systemctl reload nginx
curl -fsS https://${host}/scene/ >/dev/null
curl -fsS https://${host}/ >/dev/null
trap - ERR
printf 'Scene preview published. Rollback backup: %s\\n' "$backup"
`,'glb-publish-scene-preview'));
}finally{console.log(await run(cleanup,'glb-scene-upload-cleanup'));}
