import fs from 'node:fs';
import crypto from 'node:crypto';
import {spawnSync} from 'node:child_process';
import {readWave} from '../services/tencent-speech.mjs';
const dir='scene-preview/assets/avatar/audio',work='work/ipa-reference';
const file=dir+'/pronunciation-units.json',data=JSON.parse(fs.readFileSync(file));
const additions={w:['w','w'],aa:['ɑː','ɑ'],iy:['iː','i'],eh:['e','ɛ'],r:['ɹ','ɻ'],ay:['aɪ','En-us-I.ogg'],ey:['eɪ','En-us-A.ogg']};
for(const [id,[symbol,recording]]of Object.entries(additions)){
 let url,page,license,author,description='Independent phonetic recording';
 if(recording.endsWith('.ogg')){
  const q=new URL('https://commons.wikimedia.org/w/api.php');q.search=new URLSearchParams({action:'query',format:'json',prop:'imageinfo',iiprop:'url|extmetadata',titles:'File:'+recording});
  const j=await(await fetch(q)).json(),info=Object.values(j.query.pages)[0].imageinfo[0];
  if(info.extmetadata.License.value!=='pd')throw Error('Expected public domain');
  url=info.url;page=info.descriptionurl;license=page;author='Wikimedia Commons contributor (PD-self)';
  description='Complete General American single-phoneme letter name; no word cuts or splicing';
 }else{
  url=`https://raw.githubusercontent.com/NewDanishPhonetics/IPA-sound-files/main/${encodeURIComponent(recording)}.wav`;
  page='https://github.com/NewDanishPhonetics/IPA-sound-files';license='https://creativecommons.org/publicdomain/zero/1.0/';author='Ruben Schachtenhaufen';
  if(id==='r')description='Retroflex approximant [ɻ], an American English /r/ realization, not a trill';
 }
 const input=`${work}/course-${id}.${recording.endsWith('.ogg')?'ogg':'wav'}`,output=`${dir}/phoneme_${id}.wav`;
 if(!fs.existsSync(input)){const r=await fetch(url);if(!r.ok)throw Error(r.status);fs.writeFileSync(input,Buffer.from(await r.arrayBuffer()));}
 const r=spawnSync('D:/newApp/jianying/JianyingPro/11.5.3.14501/ffmpeg.exe',['-hide_banner','-loglevel','error','-y','-i',input,'-ac','1','-ar','16000','-c:a','pcm_s16le',output],{windowsHide:true});if(r.status!==0)throw Error(r.stderr);
 const {duration}=readWave(fs.readFileSync(output));
 data[`phoneme_${id}`]={symbol,kind:'phoneme',bundled:true,reference:true,voice:'phonetic-reference',duration,cues:[{time:0,id:0},{time:duration,id:0}],source:{url,page,license,author,description,change:'Resampled only; complete recording, no linguistic cuts, pitch changes or concatenation',sha256:crypto.createHash('sha256').update(fs.readFileSync(input)).digest('hex')}};
 console.log(id,duration);
}
fs.writeFileSync(file,JSON.stringify(data,null,2)+'\n');
fs.writeFileSync(dir+'/IPA-reference-attribution.json',JSON.stringify(Object.entries(data).filter(([,v])=>v.reference).map(([key,v])=>({key,...v.source})),null,2)+'\n');
