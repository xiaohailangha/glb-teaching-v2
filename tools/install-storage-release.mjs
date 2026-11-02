import fs from 'node:fs/promises';
import {upload,remote} from './remote.mjs';
import {validateRelease} from '../services/content-store.mjs';
const release=validateRelease(JSON.parse(await fs.readFile('work/course-release/staged.json','utf8')));
await upload([['work/course-release/staged.json','/root/snow-course-release.json'],['tools/backup-project.mjs','/root/snow-backup-project.mjs'],['.secrets/backup-cos.json','/root/snow-backup-cos.json'],['.secrets/project-backup.key','/root/snow-project-backup.key']]);
console.log(await remote(`#!/bin/bash
set -euo pipefail
test "$(hostname)" = VM-0-11-ubuntu
install -d -o glbapp -g glbapp -m 700 /var/lib/snow-speaks-app/content/releases
install -o glbapp -g glbapp -m 600 /root/snow-course-release.json /var/lib/snow-speaks-app/content/releases/${release.id}.json
python3 - <<'PY'
import pathlib,json,os
p=pathlib.Path('/var/lib/snow-speaks-app/content/current.json')
if not p.exists():
 p.write_text(json.dumps({'active':'${release.id}','published':['${release.id}']}));p.chmod(0o600)
 import shutil;shutil.chown(p,user='glbapp',group='glbapp')
print('Course release staged; existing active release preserved.')
PY
install -d -m 755 /opt/glb-teaching/tools
install -m 644 /root/snow-backup-project.mjs /opt/glb-teaching/tools/backup-project.mjs
install -m 600 /root/snow-backup-cos.json /opt/glb-teaching/.secrets/backup-cos.json
if test -f /opt/glb-teaching/.secrets/project-backup.key; then cmp /root/snow-project-backup.key /opt/glb-teaching/.secrets/project-backup.key; else install -m 600 /root/snow-project-backup.key /opt/glb-teaching/.secrets/project-backup.key; fi
rm /root/snow-project-backup.key /root/snow-backup-cos.json
cat > /etc/systemd/system/snow-project-backup.service <<'UNIT'
[Unit]
Description=Snow Speaks encrypted off-host backup with restore verification
[Service]
Type=oneshot
User=root
WorkingDirectory=/opt/glb-teaching
Environment=SNOW_DATA_DIR=/var/lib/snow-speaks-app
Environment=SNOW_ADMIN_DATA_DIR=/var/lib/snow-speaks-admin
ExecStart=/opt/glb-runtime/node/bin/node /opt/glb-teaching/tools/backup-project.mjs
UMask=0077
PrivateTmp=true
NoNewPrivileges=true
UNIT
cat > /etc/systemd/system/snow-project-backup.timer <<'UNIT'
[Unit]
Description=Daily Snow Speaks project backup
[Timer]
OnCalendar=*-*-* 03:15:00 Asia/Shanghai
RandomizedDelaySec=300
Persistent=true
[Install]
WantedBy=timers.target
UNIT
systemctl daemon-reload
echo 'Backup schedule installed; enable after application modules are deployed.'
`,'snow-storage-release'));
