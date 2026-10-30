#!/bin/bash
set -eu
test "$(hostname)" = VM-0-11-ubuntu
python3 - <<'PY'
import subprocess,json
def run(*args):
    p=subprocess.run(args,capture_output=True,text=True)
    return {'exit':p.returncode,'output':p.stdout.strip(),'error':p.stderr.strip()}
checks={
 'services':run('systemctl','is-active','glb-teaching','nginx'),
 'boot':run('uptime','-s'),
 'ipv6Addresses':run('ip','-j','-6','addr','show','scope','global'),
 'ipv6Routes':run('ip','-j','-6','route'),
 'listeners':run('ss','-lntp'),
 'renewal':run('systemctl','is-enabled','glb-cert-renew.timer'),
 'renewalActive':run('systemctl','is-active','glb-cert-renew.timer'),
 'nginxValidation':run('nginx','-t'),
 'localSpeech':run('curl','-fsS','--max-time','10','http://127.0.0.1:5296/api/speech/status'),
 'ipv6LocalHttps':run('curl','-g','-6','-sS','--max-time','5','https://[::1]/'),
}
print(json.dumps(checks))
PY
