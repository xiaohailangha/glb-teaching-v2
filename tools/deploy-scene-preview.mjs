// Validates locally by default. Use --apply to publish this repository only.
import fs from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {command,upload,remote} from './remote.mjs';
import {outputRoot,webOutput} from './local-paths.mjs';
process.chdir(fileURLToPath(new URL('../',import.meta.url)));
const archive=path.join(outputRoot,'deploy-scene-preview.tar.gz');
const release=JSON.parse(await fs.readFile(path.join(webOutput,'scene-release.json'),'utf8'));
await fs.access(path.join(webOutput,release.mainFile));
await command('tar',['-czf',archive,'--exclude=./assets/flutter_scene_generated/*.fsceneb','-C',webOutput,'.']);
console.log('scene-preview: package verified. '+archive);
if(!process.argv.includes('--apply')){console.log('Review complete. Add --apply to publish.');process.exit(0);}
const uploaded='/root/snow-scene-preview-'+Date.now()+'.tar.gz';
await upload([[archive,uploaded]]);
console.log(await remote(`#!/bin/bash
set -eu
webroot=/opt/glb-teaching/build/web/scene
stage=$(mktemp -d /opt/snow-scene-preview-XXXXXX)
backup=/opt/snow-scene-preview-backup-$(date +%s)
tar -xzf ${uploaded} -C "$stage"
mkdir -p "$backup"
cp -a "$webroot" "$backup/web"
rollback() { cp -a "$backup/web/." "$webroot/"; }
trap rollback ERR
cp -a "$stage/"* "$webroot/"
chown -R glbapp:glbapp "$webroot"
curl -kfsS https://49.233.179.83/scene/ | grep -Fq "${release.bootstrapFile}" 
curl -kfsS https://49.233.179.83/scene/scene-release.json | grep -Fq "${release.mainSha256}"
trap - ERR
printf 'Published scene-preview. Backup: %s\n' "$backup"
`,'snow-scene-preview-deploy'));
