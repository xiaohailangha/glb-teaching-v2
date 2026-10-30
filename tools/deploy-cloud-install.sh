#!/bin/bash
set -euo pipefail
test -x /opt/glb-runtime/node/bin/node
test -x /opt/glb-runtime/certbot/bin/certbot
test -f /root/glb-release.tar.gz
test ! -e /opt/glb-teaching/server.mjs
tar -xzf /root/glb-release.tar.gz -C /opt/glb-teaching
install -d -o glbapp -g glbapp -m 700 /opt/glb-teaching/.secrets
install -d -o glbapp -g glbapp -m 700 /opt/glb-teaching/work/tencent-cache
install -o glbapp -g glbapp -m 600 /root/glb-tencent.json /opt/glb-teaching/.secrets/tencent.json
python3 - <<'PY'
import os,json,subprocess,pathlib,gzip,hashlib
root=pathlib.Path('/opt/glb-teaching/build/web')
cred=json.load(open('/root/glb-preview.json'))
if cred.get('accessMode') != 'public':
    hashed=subprocess.check_output(['openssl','passwd','-6','-stdin'],input=cred['password'].encode()).decode().strip()
    open('/etc/nginx/glb-passwords','w').write(cred['username']+':'+hashed+'\n')
    os.chmod('/etc/nginx/glb-passwords',0o640)
model=root/'assets/assets/avatar/models/storm-performance.glb'
assert model.is_file(),model
revision=hashlib.sha256(model.read_bytes()).hexdigest()
parts=model.parent/'storm-parts'
parts.mkdir(exist_ok=True)
with model.open('rb') as src:
    index=0
    while chunk:=src.read(1024*1024):
        target=parts/f'{index}.bin'
        target.write_bytes(chunk)
        with gzip.open(str(target)+'.gz','wb',compresslevel=5) as out:out.write(chunk)
        index+=1
for f in root.rglob('*'):
    if f.is_file() and f.suffix in ('.js','.json','.wasm','.glb','.ttf','.css','.html') and f.stat().st_size>1024:
        with f.open('rb') as src,gzip.open(str(f)+'.gz','wb',compresslevel=5) as dst:
            while chunk:=src.read(1024*1024):dst.write(chunk)
template=pathlib.Path('/root/glb-nginx.conf').read_text()
template=template.replace('__MODEL_SIZE__',str(model.stat().st_size)).replace('__MODEL_REVISION__',revision)
pathlib.Path('/etc/nginx/sites-available/glb-teaching').write_text(template)
print(json.dumps({'modelBytes':model.stat().st_size,'parts':index,'gzipBytes':sum(f.stat().st_size for f in parts.glob('*.gz')),'revision':revision}))
PY
if test -f /etc/nginx/glb-passwords; then chown root:www-data /etc/nginx/glb-passwords; fi
chmod -R o+rX /opt/glb-teaching/build
cp /root/glb-teaching.service /etc/systemd/system/glb-teaching.service
cp /root/glb-cert-renew.service /etc/systemd/system/glb-cert-renew.service
cp /root/glb-cert-renew.timer /etc/systemd/system/glb-cert-renew.timer
systemctl daemon-reload
systemctl enable --now glb-teaching
test ! -e /etc/nginx/sites-enabled/default || mv /etc/nginx/sites-enabled/default /root/glb-nginx-default.disabled
ln -s /etc/nginx/sites-available/glb-teaching /etc/nginx/sites-enabled/glb-teaching
# Initial HTTP config serves ACME only; application is never exposed without authentication.
cp /etc/nginx/sites-available/glb-teaching /root/glb-nginx-https.ready
cat > /etc/nginx/sites-available/glb-teaching <<'EOF'
server {
  listen 80 default_server;
  server_name 49.233.179.83;
  location ^~ /.well-known/acme-challenge/ { root /var/www/glb-acme; }
  location / { return 503; }
}
EOF
nginx -t
systemctl reload nginx
/opt/glb-runtime/certbot/bin/certbot certonly --non-interactive --agree-tos --register-unsafely-without-email --preferred-profile shortlived --webroot --webroot-path /var/www/glb-acme --ip-address 49.233.179.83 --cert-name glb-teaching-ip --deploy-hook 'systemctl reload nginx'
cp /root/glb-nginx-https.ready /etc/nginx/sites-available/glb-teaching
nginx -t
systemctl reload nginx
systemctl enable --now glb-cert-renew.timer
systemctl is-active glb-teaching nginx
echo GLB_INSTALL_COMPLETE
