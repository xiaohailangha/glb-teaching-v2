#!/bin/bash
set -eu
hostname
cat /etc/os-release
df -h /
free -m
ss -lntup
systemctl list-units --type=service --state=running --no-pager
command -v node || true
command -v nginx || true
command -v certbot || true
test ! -d /opt/glb-teaching || ls -ld /opt/glb-teaching
ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
