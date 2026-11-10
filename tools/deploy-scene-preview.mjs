// Isolated /scene/ release on the already authorized Tencent preview host.
// Application release; persistent data remains outside the code directory.
import fs from 'node:fs/promises';
import {spawn} from 'node:child_process';
import {api} from './tencent-deploy-api.mjs';

const enableTestAuth=process.argv.includes('--test-auth');
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
if(!(await fs.readFile('scene-preview/build/web/index.html','utf8')).includes('<base href="/scene/">'))throw Error('Build with --base-href /scene/ before deploying this route.');
await fs.access('.secrets/cos-scene-assets.json');
await fs.mkdir('work/cloud-deploy',{recursive:true});
await command('tar',['-czf','work/cloud-deploy/curriculum.tar.gz','data/curriculum/plan-3000.json','data/curriculum/access.json','data/curriculum/sample.json','data/curriculum/checks.json','data/curriculum/word-checks.json','data/curriculum/audio-release.json','services/curriculum.mjs','services/curriculum-evidence.mjs','services/curriculum-media.mjs']);
await command('tar',['-czf','work/cloud-deploy/scene-preview.tar.gz','--exclude=./assets/flutter_scene_generated/*.fsceneb','-C','scene-preview/build/web','.']);
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
  ['work/cloud-deploy/curriculum.tar.gz','glb-curriculum.tar.gz'],
  ['services/cos-assets.mjs','glb-scene-cos-assets.mjs'],
  ['services/speech-http.mjs','glb-scene-speech-http.mjs'],
  ['services/live-recognition.mjs','glb-scene-live-recognition.mjs'],
  ['services/storage-paths.mjs','glb-storage-paths.mjs'],
  ['services/content-store.mjs','glb-content-store.mjs'],
  ['services/content-http.mjs','glb-content-http.mjs'],
  ['services/backup-codec.mjs','glb-backup-codec.mjs'],
  ['services/tencent-speech.mjs','glb-tencent-speech.mjs'],
  ['services/auth-http.mjs','glb-auth-http.mjs'],
  ['services/learning-http.mjs','glb-learning-http.mjs'],
  ['services/learning-store.mjs','glb-learning-store.mjs'],
  ['data/course-catalog.json','glb-course-catalog.json'],
  ['services/tencent-sms.mjs','glb-tencent-sms.mjs'],
  ['server.mjs','glb-auth-server.mjs'],
  ['.secrets/cos-scene-assets.json','glb-scene-assets.json'],
 ])await command('scp',[...ssh,source,`root@${host}:/root/${target}`]);
 console.log('Scene release uploaded.');
 console.log(await run(`#!/bin/bash
set -euo pipefail
test "$(hostname)" = VM-0-11-ubuntu
backup=/opt/glb-backups/before-scene-$(date -u +%Y%m%dT%H%M%SZ)
install -d -m 700 "$backup"
python3 - "$backup" <<'PY'
import pathlib,sqlite3,subprocess,sys
pid=subprocess.check_output(['systemctl','show','glb-teaching','-p','MainPID','--value'],text=True).strip()
env=dict(x.split('=',1) for x in pathlib.Path('/proc/'+pid+'/environ').read_text().split(chr(0)) if '=' in x)
root=pathlib.Path(env.get('SNOW_DATA_DIR','/opt/glb-teaching/var'))
for db in root.rglob('*.sqlite'):
    target=pathlib.Path(sys.argv[1])/'database'/db.relative_to(root)
    target.parent.mkdir(parents=True,exist_ok=True)
    with sqlite3.connect('file:'+str(db)+'?mode=ro',uri=True) as src, sqlite3.connect(target) as dst: src.backup(dst)
print('Consistent account database snapshots saved.')
PY
cp /etc/nginx/sites-available/glb-teaching "$backup/nginx.conf"
if test -f /etc/systemd/system/glb-teaching.service.d/auth-test.conf; then cp /etc/systemd/system/glb-teaching.service.d/auth-test.conf "$backup/auth-test.conf"; fi
cp /opt/glb-teaching/server.mjs "$backup/server.mjs"
if test -d /opt/glb-teaching/data/curriculum; then cp -a /opt/glb-teaching/data/curriculum "$backup/curriculum"; fi
for name in curriculum curriculum-evidence curriculum-media; do
 if test -f /opt/glb-teaching/services/$name.mjs; then cp /opt/glb-teaching/services/$name.mjs "$backup/$name.mjs"; fi
done
for name in auth-http tencent-sms learning-http learning-store storage-paths content-store content-http backup-codec tencent-speech; do
 if test -f /opt/glb-teaching/services/$name.mjs; then cp /opt/glb-teaching/services/$name.mjs "$backup/$name.mjs"; fi
done
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
 cp "$backup/server.mjs" /opt/glb-teaching/server.mjs
 if test -d "$backup/curriculum"; then cp -a "$backup/curriculum/." /opt/glb-teaching/data/curriculum/; fi
 for name in curriculum curriculum-evidence curriculum-media; do
  if test -f "$backup/$name.mjs"; then cp "$backup/$name.mjs" /opt/glb-teaching/services/$name.mjs; fi
 done
 if test -f "$backup/course-catalog.json"; then cp "$backup/course-catalog.json" /opt/glb-teaching/data/course-catalog.json; fi
 for name in auth-http tencent-sms learning-http learning-store storage-paths content-store content-http backup-codec tencent-speech; do
  if test -f "$backup/$name.mjs"; then cp "$backup/$name.mjs" /opt/glb-teaching/services/$name.mjs; fi
 done
 cp "$backup/cos-assets.mjs" /opt/glb-teaching/services/cos-assets.mjs
 cp "$backup/speech-http.mjs" /opt/glb-teaching/services/speech-http.mjs
 if test -f "$backup/live-recognition.mjs"; then cp "$backup/live-recognition.mjs" /opt/glb-teaching/services/live-recognition.mjs; fi
 if test -f "$backup/scene-config.json"; then install -o glbapp -g glbapp -m 600 "$backup/scene-config.json" /opt/glb-teaching/.secrets/cos-scene-assets.json; fi
 if test "$scene_installed" = 1 && test -d /opt/glb-teaching/build/web/scene; then mv /opt/glb-teaching/build/web/scene "$stage.failed"; fi
 if test -d "$backup/scene"; then mv "$backup/scene" /opt/glb-teaching/build/web/scene; fi
 if test -f "$backup/auth-test.conf"; then cp "$backup/auth-test.conf" /etc/systemd/system/glb-teaching.service.d/auth-test.conf; elif test '${enableTestAuth}' = true; then rm -f /etc/systemd/system/glb-teaching.service.d/auth-test.conf; fi
 systemctl daemon-reload
 systemctl restart glb-teaching
 nginx -t && systemctl reload nginx
 echo SCENE_RELEASE_ROLLED_BACK >&2
}
trap rollback ERR
backend_changed=1
tar -xzf /root/glb-curriculum.tar.gz -C /opt/glb-teaching
chown -R glbapp:glbapp /opt/glb-teaching/data/curriculum
for name in curriculum curriculum-evidence curriculum-media; do
 chown glbapp:glbapp /opt/glb-teaching/services/$name.mjs
 /opt/glb-runtime/node/bin/node --check /opt/glb-teaching/services/$name.mjs
done
(cd /opt/glb-teaching && /opt/glb-runtime/node/bin/node --input-type=module -e "import {validateCurriculum} from './services/curriculum.mjs'; validateCurriculum();")
if ! cmp -s /root/glb-course-catalog.json /opt/glb-teaching/data/course-catalog.json; then backend_changed=1; fi
if test -f /opt/glb-teaching/data/course-catalog.json; then cp /opt/glb-teaching/data/course-catalog.json "$backup/course-catalog.json"; fi
/opt/glb-runtime/node/bin/node -e "require('node:sqlite')"
for name in auth-http tencent-sms learning-http learning-store storage-paths content-store content-http backup-codec tencent-speech; do
 /opt/glb-runtime/node/bin/node --check /root/glb-$name.mjs
 if ! cmp -s /root/glb-$name.mjs /opt/glb-teaching/services/$name.mjs; then backend_changed=1; fi
done
/opt/glb-runtime/node/bin/node --check /root/glb-auth-server.mjs
if ! cmp -s /root/glb-auth-server.mjs /opt/glb-teaching/server.mjs; then backend_changed=1; fi
if ! cmp -s /root/glb-scene-speech-http.mjs /opt/glb-teaching/services/speech-http.mjs || ! cmp -s /root/glb-scene-live-recognition.mjs /opt/glb-teaching/services/live-recognition.mjs; then backend_changed=1; fi
/opt/glb-runtime/node/bin/node --check /root/glb-scene-speech-http.mjs
/opt/glb-runtime/node/bin/node --check /root/glb-scene-live-recognition.mjs
if ! cmp -s /root/glb-scene-cos-assets.mjs /opt/glb-teaching/services/cos-assets.mjs || ! cmp -s /root/glb-scene-assets.json /opt/glb-teaching/.secrets/cos-scene-assets.json; then backend_changed=1; fi
if test -d /opt/glb-teaching/build/web/scene; then mv /opt/glb-teaching/build/web/scene "$backup/scene"; fi
mv "$stage" /opt/glb-teaching/build/web/scene
scene_installed=1
install -d -o glbapp -g glbapp -m 755 /opt/glb-teaching/data
install -o glbapp -g glbapp -m 644 /root/glb-course-catalog.json /opt/glb-teaching/data/course-catalog.json
install -o glbapp -g glbapp -m 644 /root/glb-auth-server.mjs /opt/glb-teaching/server.mjs
install -d -o glbapp -g glbapp -m 700 /opt/glb-teaching/work/auth-private
for name in auth-http tencent-sms learning-http learning-store storage-paths content-store content-http backup-codec tencent-speech; do
 install -o glbapp -g glbapp -m 644 /root/glb-$name.mjs /opt/glb-teaching/services/$name.mjs
done
install -o glbapp -g glbapp -m 644 /root/glb-scene-speech-http.mjs /opt/glb-teaching/services/speech-http.mjs
install -o glbapp -g glbapp -m 644 /root/glb-scene-live-recognition.mjs /opt/glb-teaching/services/live-recognition.mjs
install -o glbapp -g glbapp -m 644 /root/glb-scene-cos-assets.mjs /opt/glb-teaching/services/cos-assets.mjs
install -o glbapp -g glbapp -m 600 /root/glb-scene-assets.json /opt/glb-teaching/.secrets/cos-scene-assets.json
python3 - <<'PY'
from pathlib import Path
p=Path('/etc/nginx/sites-available/glb-teaching')
s=p.read_text()
if 'location = /api/auth/learning/curriculum/oral' not in s:
    marker='  location ^~ /api/auth/'
    assert marker in s
    block='''  location = /api/auth/learning/curriculum/oral {
    proxy_pass http://127.0.0.1:5296;
    proxy_set_header Host $http_host;
    proxy_set_header Origin $http_origin;
    proxy_set_header Sec-Fetch-Site $http_sec_fetch_site;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header Cookie $http_cookie;
    client_max_body_size 950k;
    proxy_read_timeout 100s;
    add_header Cache-Control "private, no-store" always;
  }
'''
    s=s.replace(marker,block+marker,1)
    p.write_text(s)
if 'location ^~ /api/auth/' not in s:
    marker='  location ^~ /api/speech/ {'
    assert marker in s
    block='''  location ^~ /api/auth/ {
    proxy_pass http://127.0.0.1:5296;
    proxy_set_header Host $http_host;
    proxy_set_header Origin $http_origin;
    proxy_set_header Sec-Fetch-Site $http_sec_fetch_site;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header Cookie $http_cookie;
    proxy_set_header Authorization "";
    proxy_read_timeout 25s;
    client_max_body_size 4k;
    add_header Cache-Control "private, no-store" always;
  }
'''
    s=s.replace(marker,block+marker)
    p.write_text(s)
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
if test '${enableTestAuth}' = true; then
 install -d -m 755 /etc/systemd/system/glb-teaching.service.d
 printf '[Service]\\nEnvironment=AUTH_TEST_MODE=1\\n' > /etc/systemd/system/glb-teaching.service.d/auth-test.conf
 systemctl daemon-reload
 backend_changed=1
fi
if test "$backend_changed" = 1; then systemctl restart glb-teaching; fi
curl --retry 5 --retry-connrefused --retry-delay 1 -fsS -H 'Host: 127.0.0.1:5296' http://127.0.0.1:5296/api/speech/status >/dev/null
curl --retry 3 --retry-delay 1 -fsS -H 'Host: 127.0.0.1:5296' http://127.0.0.1:5296/api/assets/scene-manifest >/dev/null
curl --retry 3 --retry-delay 1 -fsS -H 'Host: 127.0.0.1:5296' http://127.0.0.1:5296/api/auth/status >/dev/null
systemctl reload nginx
curl --retry 5 --retry-all-errors --retry-delay 1 -fsS https://${host}/api/auth/status >/dev/null
curl -fsS https://${host}/scene/ >/dev/null
curl -fsS https://${host}/ >/dev/null
trap - ERR
printf 'Scene preview published. Rollback backup: %s\\n' "$backup"
`,'glb-publish-scene-preview'));
}finally{console.log(await run(cleanup,'glb-scene-upload-cleanup'));}
