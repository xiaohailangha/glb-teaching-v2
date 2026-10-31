import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
const origin='https://49.233.179.83/scene/';
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
async function same(file){const response=await fetch(origin+file,{signal:AbortSignal.timeout(30000)});assert.equal(response.status,200,file);assert.equal(hash(Buffer.from(await response.arrayBuffer())),hash(await fs.readFile('scene-preview/build/web/'+file)),file);}
for(const name of ['adult-drinks','adult-polite','adult-shop']){await same(`assets/assets/avatar/courses/${name}.json`);console.log('PASS '+name+' published exactly');}
const m=JSON.parse(await fs.readFile('scene-preview/assets/avatar/audio/unit-one-prompts.json','utf8'));
for(const key of Object.keys(m)) await same(`assets/assets/avatar/audio/${key}.wav`);
await same('assets/assets/avatar/audio/unit-one-prompts.json');
console.log('PASS all 24 new voices and aligned manifest match release');
for(const key of ['water','milk','tea','coffee']) await same(`assets/assets/avatar/images/${key}.svg`);
for(const key of ['phoneme_z','phoneme_y'])await same(`assets/assets/avatar/audio/${key}.wav`);
console.log('PASS drink illustrations and independent IPA sounds match release');
