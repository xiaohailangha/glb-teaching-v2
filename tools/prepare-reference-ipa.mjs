// Isolated phonetic recordings, never cut from a vocabulary word.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {spawnSync} from 'node:child_process';
import {readWave} from '../services/tencent-speech.mjs';
const dir='scene-preview/assets/avatar/audio',work='work/ipa-reference';
fs.mkdirSync(work,{recursive:true});
const ffmpeg='D:/newApp/jianying/JianyingPro/11.5.3.14501/ffmpeg.exe';
const symbols={ae:'æ',p:'p',l:'l',b:'b',n:'n',k:'k',t:'t',d:'d',aw:'ɔ',g:'g',f:'f',sh:'ʃ',m:'m',uu:'u',s:'s',ah:'ʌ',h:'h',th:'θ',ng:'ŋ'};
const commons={schwa:'Mid-central vowel.ogg',ih:'Near-close near-front unrounded vowel.ogg',uh:'Near-close near-back rounded vowel.ogg'};
const original=JSON.parse(fs.readFileSync(path.join(dir,'pronunciation-units.json')));
const report=[];
async function download(url,file){if(!fs.existsSync(file)){const r=await fetch(url);if(!r.ok)throw Error(`${r.status}: ${url}`);fs.writeFileSync(file,Buffer.from(await r.arrayBuffer()));}}
await download('https://raw.githubusercontent.com/NewDanishPhonetics/IPA-sound-files/main/LICENSE',path.join(dir,'IPA-reference-CC0.txt'));
for(const id of [...Object.keys(symbols),...Object.keys(commons)]) {
 let url,author,license,page;
 if(symbols[id]) {
  page='https://github.com/NewDanishPhonetics/IPA-sound-files';
  url=`https://raw.githubusercontent.com/NewDanishPhonetics/IPA-sound-files/main/${encodeURIComponent(symbols[id])}.wav`;
  author='Ruben Schachtenhaufen';license='https://creativecommons.org/publicdomain/zero/1.0/';
 } else {
  const query=new URL('https://commons.wikimedia.org/w/api.php');
  query.search=new URLSearchParams({action:'query',format:'json',prop:'imageinfo',iiprop:'url|extmetadata',titles:'File:'+commons[id]});
  const r=await fetch(query);if(!r.ok)throw Error('Commons metadata unavailable');
  const data=await r.json(), info=Object.values(data.query.pages)[0].imageinfo[0];
  url=info.url;page=info.descriptionurl;license=info.extmetadata.LicenseUrl.value;
  author=info.extmetadata.Artist.value.replace(/<[^>]*>/g,'');
 }
 const input=path.join(work,id+(symbols[id]?'.wav':'.ogg')),output=path.join(dir,`phoneme_${id}.wav`);
 await download(url,input);
 const conversion=spawnSync(ffmpeg,['-hide_banner','-loglevel','error','-y','-i',input,'-ac','1','-ar','16000','-c:a','pcm_s16le',output],{windowsHide:true});
 if(conversion.status!==0)throw Error(conversion.stderr?.toString());
 const {duration}=readWave(fs.readFileSync(output));
 original[`phoneme_${id}`]={symbol:original[`phoneme_${id}`].symbol,kind:'phoneme',bundled:true,reference:true,voice:'phonetic-reference',duration,cues:[{time:0,id:0},{time:duration,id:0}],source:{url,page,author,license,change:'Resampled to 16 kHz mono PCM; no linguistic cuts, no pitch/time changes',sha256:crypto.createHash('sha256').update(fs.readFileSync(input)).digest('hex')}};
 report.push({key:`phoneme_${id}`,...original[`phoneme_${id}`].source});
 console.log('reference',id,duration);
}
// A syllable and a diphthong are not replaced with unrelated isolated sounds.
delete original.group_schwa_l;delete original.phoneme_ow;
for(const key of ['group_schwa_l','phoneme_ow'])fs.rmSync(path.join(dir,key+'.wav'),{force:true});
fs.writeFileSync(path.join(dir,'pronunciation-units.json'),JSON.stringify(original,null,2)+'\n');
fs.writeFileSync(path.join(dir,'IPA-reference-attribution.json'),JSON.stringify(report,null,2)+'\n');
