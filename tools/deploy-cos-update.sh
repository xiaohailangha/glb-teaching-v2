#!/bin/bash
set -euo pipefail
test "$(hostname)" = VM-0-11-ubuntu
test -f /opt/glb-teaching/server.mjs
backup=/opt/glb-backups/before-cos-$(date -u +%Y%m%dT%H%M%SZ)
install -d -m 700 "$backup"
cp -a /opt/glb-teaching "$backup/app"
cp /etc/nginx/sites-available/glb-teaching "$backup/nginx.conf"
cp /etc/systemd/system/glb-teaching.service "$backup/service"
stage=$(mktemp -d /opt/glb-cos-stage-XXXXXX)
tar -xzf /root/glb-cos-release.tar.gz -C "$stage"
cd "$stage"
/opt/glb-runtime/node/bin/node --input-type=module -e "await import('./services/cos-assets.mjs'); console.log('COS dependencies loaded')"
# Preserve the already generated server fallback chunks.
cp -a /opt/glb-teaching/build/web/assets/assets/avatar/models/storm-parts "$stage/build/web/assets/assets/avatar/models/"
python3 - "$stage/build/web" <<'PY'
import sys,pathlib,gzip,shutil
root=pathlib.Path(sys.argv[1])
for f in root.rglob('*'):
    if f.is_file() and f.suffix in ('.js','.json','.wasm','.glb','.ttf','.css','.html') and f.stat().st_size>1024:
        with f.open('rb') as src,gzip.open(str(f)+'.gz','wb',compresslevel=5) as dst:
            shutil.copyfileobj(src,dst)
PY
chmod -R a+rX "$stage/build" "$stage/node_modules" "$stage/services"
systemctl stop glb-teaching
cp -a "$stage/server.mjs" "$stage/services" "$stage/node_modules" "$stage/package.json" "$stage/package-lock.json" /opt/glb-teaching/
mv /opt/glb-teaching/build/web "$backup/previous-web"
mv "$stage/build/web" /opt/glb-teaching/build/web
install -o glbapp -g glbapp -m 600 /root/glb-cos-assets.json /opt/glb-teaching/.secrets/cos-assets.json
cp /root/glb-teaching.service /etc/systemd/system/glb-teaching.service
systemctl daemon-reload
systemctl start glb-teaching
bash /root/deploy-cloud-configure.sh
curl --retry 5 --retry-connrefused --retry-delay 1 -fsS -H 'Host: 127.0.0.1:5296' http://127.0.0.1:5296/api/assets/model-manifest -o /tmp/glb-cos-manifest.json
python3 - <<'PY'
import json,os
x=json.load(open('/tmp/glb-cos-manifest.json'))
assert len(x['parts'])==147
print(json.dumps({'cosParts':len(x['parts']),'modelBytes':x['size']}))
os.remove('/tmp/glb-cos-manifest.json')
PY
printf 'Rollback backup: %s\n' "$backup"
echo GLB_COS_READY
