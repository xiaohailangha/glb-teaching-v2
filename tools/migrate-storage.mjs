import {remote} from './remote.mjs';
console.log(await remote(`#!/bin/bash
set -euo pipefail
test "$(hostname)" = VM-0-11-ubuntu
backup=/opt/glb-backups/storage-$(date -u +%Y%m%dT%H%M%SZ)
install -d -m 700 "$backup"
export STORAGE_BACKUP="$backup"
systemctl stop glb-teaching snow-speaks-admin
trap 'systemctl start glb-teaching snow-speaks-admin' EXIT
python3 - <<'PY'
import os,pathlib,shutil,sqlite3,hashlib
root=pathlib.Path(os.environ['STORAGE_BACKUP'])
pairs=[('/opt/glb-teaching/work/auth-private','/var/lib/snow-speaks-app/auth','glbapp'),('/opt/glb-teaching/work/learning-private','/var/lib/snow-speaks-app/learning','glbapp'),('/opt/glb-teaching/work/tencent-cache','/var/cache/snow-speaks-app/tts','glbapp'),('/opt/snow-speaks-admin/work/admin-private','/var/lib/snow-speaks-admin/management','snowadmin')]
for old,new,owner in pairs:
 a,b=pathlib.Path(old),pathlib.Path(new)
 if a.is_symlink():
  assert a.resolve()==b.resolve() and b.is_dir()
  continue
 assert not b.exists(), 'Destination already exists: '+new
 if not a.exists(): a.mkdir(parents=True,mode=0o700)
 for db in a.glob('*.sqlite'):
  with sqlite3.connect(db) as conn:
   assert conn.execute('PRAGMA quick_check').fetchone()[0]=='ok'
   conn.execute('PRAGMA wal_checkpoint(TRUNCATE)')
 shutil.copytree(a,b)
 for source in a.rglob('*'):
  if source.is_file(): assert hashlib.sha256(source.read_bytes()).digest()==hashlib.sha256((b/source.relative_to(a)).read_bytes()).digest()
 shutil.move(str(a),str(root/a.name))
 a.symlink_to(b,target_is_directory=True)
 for item in [b,*b.rglob('*')]: shutil.chown(item,user=owner,group=owner)
 print(a.name+': copied, hashes verified, legacy path linked')
for name,owner in [('/var/lib/snow-speaks-app','glbapp'),('/var/cache/snow-speaks-app','glbapp'),('/var/lib/snow-speaks-admin','snowadmin')]:
 p=pathlib.Path(name);p.chmod(0o700);shutil.chown(p,user=owner,group=owner)
PY
install -d -o glbapp -g glbapp -m 700 /var/lib/snow-speaks-app/content
install -d /etc/systemd/system/glb-teaching.service.d /etc/systemd/system/snow-speaks-admin.service.d
printf '[Service]\\nEnvironment=SNOW_DATA_DIR=/var/lib/snow-speaks-app\\nEnvironment=SNOW_CACHE_DIR=/var/cache/snow-speaks-app\\nReadWritePaths=/var/lib/snow-speaks-app /var/cache/snow-speaks-app\\n' > /etc/systemd/system/glb-teaching.service.d/storage.conf
printf '[Service]\\nEnvironment=SNOW_ADMIN_DATA_DIR=/var/lib/snow-speaks-admin\\nReadWritePaths=/var/lib/snow-speaks-admin\\nInaccessiblePaths=/var/lib/snow-speaks-app\\n' > /etc/systemd/system/snow-speaks-admin.service.d/storage.conf
systemctl daemon-reload
systemctl start glb-teaching snow-speaks-admin
curl --retry 8 --retry-connrefused --retry-delay 1 -fsS http://127.0.0.1:5297/health
curl --retry 8 --retry-connrefused --retry-delay 1 -fsS http://127.0.0.1:5296/api/auth/status >/dev/null
trap - EXIT
echo "Storage migration verified. Original data: $backup"
`,'snow-storage-migration'));
