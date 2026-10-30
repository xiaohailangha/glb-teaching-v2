// Reproducible scene-only voice assets. Never edits the legacy root player.
import fs from 'node:fs';
import path from 'node:path';
import {teachingAudio, cacheDir, readWave, pcmWave} from '../services/tencent-speech.mjs';

const dir = 'scene-preview/assets/avatar/audio';
const voice = 403008;
const files = ['timings', 'teaching-prompts', 'course-prompts', 'pronunciation-units'];
const report = {voice, name:'云小洋', source:'https://cloud.tencent.com/document/product/1073/92668', generatedAt:new Date().toISOString(), clips:[], phonemeReview:'pending listening review'};
function segment(result, first, last) {
  const {pcm} = readWave(fs.readFileSync(path.join(cacheDir, `${result.key}.wav`)));
  const start = Math.max(0,first-.015), end = Math.min(result.duration,last+.025);
  const cut = Buffer.from(pcm.subarray(Math.floor(start*16000)*2,Math.ceil(end*16000)*2));
  // 2 ms fades suppress cut clicks without smearing a consonant release.
  for(let i=0;i<32&&i*2<cut.length;i++) {
    cut.writeInt16LE(Math.round(cut.readInt16LE(i*2)*i/32),i*2);
    const p=cut.length-2-i*2;
    cut.writeInt16LE(Math.round(cut.readInt16LE(p)*i/32),p);
  }
  const lead=.07, tail=.10;
  const wav=pcmWave(Buffer.concat([Buffer.alloc(lead*32000),cut,Buffer.alloc(tail*32000)]));
  const cues=[{time:0,id:0},...result.cues.filter(c=>c.time>=first&&c.time<last).map(c=>({...c,time:c.time-start+lead})),{time:last-start+lead,id:0}];
  return {wav,cues,duration:(wav.length-44)/32000,trim:{start,end}};
}
for (const file of files) {
  const items = JSON.parse(fs.readFileSync(path.join(dir, `${file}.json`)));
  for (const [key, item] of Object.entries(items)) {
    if (['phoneme','group'].includes(item.kind)) continue;
    const text = key==='banana' ? 'banana.' : item.text || item.symbol || key;
    const start = Date.now();
    const result = await teachingAudio(text, {voice, language:/[\u3400-\u9fff]/.test(text)?'zh':'en'});
    const audio=file==='timings'?segment(result,result.phones[0].start,result.phones.at(-1).end):{wav:fs.readFileSync(path.join(cacheDir, `${result.key}.wav`)),cues:result.cues,duration:result.duration};
    fs.writeFileSync(path.join(dir, `${key}.wav`),audio.wav);
    items[key] = {...item, text: file==='timings'?key:text, sourceText:text, voice, bundled:true, cues:audio.cues, duration:audio.duration, sourceKey:result.key, trim:audio.trim};
    report.clips.push({key, voice, duration:audio.duration, sourceDuration:result.duration, trim:audio.trim, cached:result.cached, elapsedMs:Date.now()-start});
    // Persist each success so a transient provider error can resume from cache.
    fs.writeFileSync(path.join(dir, `${file}.json`), JSON.stringify(items,null,2)+'\n');
    console.log(`${key}: ${result.duration.toFixed(2)}s (${Date.now()-start}ms)`);
  }
}
// Standalone IPA comes from licensed reference recordings, never vocabulary cuts.
await import('./prepare-reference-ipa.mjs');
// Preserve the authored 10-second performance clock with new matched cues.
const performance=Buffer.alloc(32000*10),performanceCues=[{time:0,id:0}];
let performancePart=0;
for(const [text,offset,next] of [['Hey!',.65,2.05],["Let's say apple.",2.05,4.35],['apple',4.35,6.25],['Your turn!',6.25,10]]) {
  const source=await teachingAudio(text,{voice});
  const clip=segment(source,source.phones[0].start,source.phones.at(-1).end);
  if(offset+clip.duration>next)throw Error(`Performance segment does not fit: ${text}`);
  fs.writeFileSync(path.join(dir,`performance-${performancePart++}.wav`),clip.wav);
  readWave(clip.wav).pcm.copy(performance,Math.round(offset*32000));
  performanceCues.push(...clip.cues.map(c=>({...c,time:c.time+offset})));
}
performanceCues.push({time:10,id:0});
fs.writeFileSync(path.join(dir,'performance.wav'),pcmWave(performance));
fs.writeFileSync(path.join(dir,'performance-cues.json'),JSON.stringify({voice,bundled:true,duration:10,cues:performanceCues},null,2)+'\n');
fs.mkdirSync('docs/flutter-scene',{recursive:true});
fs.writeFileSync('docs/flutter-scene/child-audio-generation.json', JSON.stringify(report,null,2)+'\n');
