import {stormModel} from './local-paths.mjs';
import fs from 'node:fs';
// Preserve the actual source-model bind transforms for attachment regressions.
const model = fs.readFileSync(stormModel);
const gltf = JSON.parse(model.subarray(20, 20 + model.readUInt32LE(12)).toString());
const rig = JSON.parse(fs.readFileSync('scene-preview/assets/avatar/models/storm-rig.json', 'utf8'));
const jointNames = new Set([rig.head, ...rig.eyes, ...rig.hair.map(joint => joint.name)]);
const nodes = gltf.nodes.filter(node => jointNames.has(node.name)).map(node => ({
 name: node.name,
 position: node.translation ?? [0, 0, 0],
 rotation: node.rotation ?? [0, 0, 0, 1],
 scale: node.scale ?? [1, 1, 1],
}));
if (nodes.length !== jointNames.size) throw new Error('Source rig joints are missing');
fs.mkdirSync('scene-preview/test/fixtures',{recursive:true});
fs.writeFileSync('scene-preview/test/fixtures/storm-joint-bind.json', JSON.stringify({rig, nodes}, null, 2) + '\n');
console.log('Generated '+nodes.length+' source-model joint bind transforms.');
