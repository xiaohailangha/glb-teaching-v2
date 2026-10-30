#!/bin/bash
set -euo pipefail
test "$(hostname)" = VM-0-11-ubuntu
test -f /opt/glb-teaching/.secrets/tencent.json
systemctl is-active --quiet glb-teaching
systemctl is-active --quiet nginx
# Only staged duplicate credentials are removed; live and local credentials remain.
rm -f /root/glb-tencent.json /root/glb-preview.json /root/glb-cos-assets.json
python3 - <<'PY'
from pathlib import Path
p=Path('/root/.ssh/authorized_keys')
lines=p.read_text().splitlines()
p.write_text('\n'.join(line for line in lines if 'glb-temporary-deploy-20261030' not in line)+'\n')
p.chmod(0o600)
print('Temporary upload SSH authorization removed; existing keys preserved.')
PY
systemctl is-enabled glb-teaching glb-cert-renew.timer
ss -lnt | grep -E ':(22|80|443|5296) '
stat -c '%a %U:%G %n' /opt/glb-teaching/.secrets/tencent.json /etc/nginx/glb-passwords
echo GLB_DEPLOYMENT_COMPLETE
