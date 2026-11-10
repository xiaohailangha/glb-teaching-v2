// Validates locally by default. Use --apply to publish this repository only.
import fs from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {command,upload,remote} from './remote.mjs';
process.chdir(fileURLToPath(new URL('../',import.meta.url)));
const web=true,archive='work/deploy-scene-preview.tar.gz';
await fs.mkdir('work',{recursive:true});
const release=JSON.parse(await fs.readFile('scene-preview/build/web/scene-release.json','utf8'));
await fs.access('scene-preview/build/web/'+release.mainFile);
await command('tar',['-czf',archive,'--exclude=./assets/flutter_scene_generated/*.fsceneb','-C','scene-preview/build/web','.']);
console.log('scene-preview: package verified. '+archive);
if(!process.argv.includes('--apply')){console.log('Review complete. Add --apply to publish.');process.exit(0);}
const uploaded='/root/snow-scene-preview-'+Date.now()+'.tar.gz';
await upload([[archive,uploaded]]);
console.log(await remote(`set -eu
target=/opt/glb-teaching
stage=$(mktemp -d /opt/snow-scene-preview-XXXXXX)
backup=/opt/snow-scene-preview-backup-$(date +%s)
tar -xzf ${uploaded} -C "$stage"
mkdir -p "$backup"
cp -a "$target/build/web" "$backup/web"
rollback() { cp -a "$backup/web/." "$target/build/web/"; }
trap rollback ERR
cp -a "$stage/." "$target/build/web/"
chown -R glbapp:glbapp "$target/build/web"
curl -kfsS https://49.233.179.83/scene/ >/dev/null
trap - ERR
printf 'Published scene-preview. Backup: %s\n' "$backup"
`,'snow-scene-preview-deploy'));
