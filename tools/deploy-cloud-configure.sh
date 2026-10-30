#!/bin/bash
set -euo pipefail
python3 - <<'PY'
import pathlib,hashlib
model=pathlib.Path('/opt/glb-teaching/build/web/assets/assets/avatar/models/storm-performance.glb')
template=pathlib.Path('/root/glb-nginx.conf').read_text().replace('__MODEL_SIZE__',str(model.stat().st_size)).replace('__MODEL_REVISION__',hashlib.sha256(model.read_bytes()).hexdigest())
pathlib.Path('/etc/nginx/sites-available/glb-teaching').write_text(template)
PY
nginx -t
systemctl reload nginx
systemctl enable --now glb-cert-renew.timer
systemctl is-active glb-teaching nginx
systemctl list-timers glb-cert-renew.timer --no-pager
echo GLB_HTTPS_READY
