#!/bin/bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq nginx curl xz-utils python3-venv
install -d -m 755 /opt/glb-teaching /opt/glb-runtime /var/www/glb-acme
if ! test -x /opt/glb-runtime/node/bin/node; then
  cd /opt/glb-runtime
  curl --fail --location --retry 2 --connect-timeout 20 --max-time 180 -o SHASUMS256.txt https://nodejs.org/dist/latest-v24.x/SHASUMS256.txt
  node_archive=$(awk '$2 ~ /linux-x64.tar.xz$/ {print $2}' SHASUMS256.txt)
  test -n "$node_archive"
  curl --fail --location --retry 2 --connect-timeout 20 --max-time 300 -O "https://nodejs.org/dist/latest-v24.x/$node_archive"
  grep " $node_archive$" SHASUMS256.txt | sha256sum -c -
  tar -xf "$node_archive"
  ln -s "${node_archive%.tar.xz}" node
fi
python3 -m venv /opt/glb-runtime/certbot
/opt/glb-runtime/certbot/bin/pip install --disable-pip-version-check 'certbot>=5.4,<6'
/opt/glb-runtime/node/bin/node --version
/opt/glb-runtime/certbot/bin/certbot --version
id glbapp >/dev/null 2>&1 || useradd --system --home-dir /opt/glb-teaching --shell /usr/sbin/nologin glbapp
echo GLB_PREPARE_COMPLETE
