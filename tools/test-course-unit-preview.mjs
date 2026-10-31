import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
const origin=process.argv.find(a=>a.startsWith('--origin='))?.slice(9)||'https://49.233.179.83/scene/';
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
async function same(file){const response=await fetch(origin+file,{signal:AbortSignal.timeout(30000)});assert.equal(response.status,200,file);assert.equal(hash(Buffer.from(await response.arrayBuffer())),hash(await fs.readFile('scene-preview/build/web/'+file)),file);}
const pictures=new Set(['water','milk','tea','coffee']);
for(const name of ['adult-drinks','adult-polite','adult-shop','adult-colors','adult-sizes','adult-numbers','adult-describe-review']){
 await same(`assets/assets/avatar/courses/${name}.json`);
 const c=JSON.parse(await fs.readFile(`scene-preview/assets/avatar/courses/${name}.json`,'utf8'));
 for(const stage of c.stages)if(stage.picture)pictures.add(stage.picture);
 console.log('PASS '+name+' published exactly');
}
for(const name of ['unit-one-prompts','unit-two-prompts']){
 const m=JSON.parse(await fs.readFile(`scene-preview/assets/avatar/audio/${name}.json`,'utf8'));
 for(const key of Object.keys(m)) await same(`assets/assets/avatar/audio/${key}.wav`);
 await same(`assets/assets/avatar/audio/${name}.json`);
 console.log(`PASS ${name}: ${Object.keys(m).length} voices and aligned manifest match release`);
}
for(const key of pictures) await same(`assets/assets/avatar/images/${key}.svg`);
for(const key of ['phoneme_z','phoneme_y','phoneme_v','phoneme_ow'])await same(`assets/assets/avatar/audio/${key}.wav`);
await same('assets/assets/avatar/audio/pronunciation-units.json');
console.log(`PASS ${pictures.size} illustrations and independent IPA sounds match release`);
