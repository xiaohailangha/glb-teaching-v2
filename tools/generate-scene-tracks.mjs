import fs from 'node:fs';
import vm from 'node:vm';
function extract(file,expression){const source=fs.readFileSync(file,'utf8').replace(/^import .*$/mg,'').replace(/export /g,'');return vm.runInNewContext(source+';('+expression+')',{Math});}
const performance=extract('assets/avatar/teaching-performance.js','tracks');
const acting=extract('assets/avatar/acting-director.js','({turn,interest,smile,lean,nod})');
const mouth=extract('assets/avatar/motion.js','({mouthNames,visemeLabels,poses})');
fs.mkdirSync('scene-preview/lib/core/avatar/scene',{recursive:true});
fs.writeFileSync('scene-preview/lib/core/avatar/scene/authored_tracks.dart',`// Generated from the current, user-approved Three.js authored tracks.\nconst Map<String,dynamic> performanceTracks = ${JSON.stringify(performance)};\nconst Map<String,dynamic> actingTracks = ${JSON.stringify(acting)};\nconst Map<String,dynamic> mouthData = ${JSON.stringify(mouth)};\n`);
