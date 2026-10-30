import fs from 'node:fs';
import path from 'node:path';
import {teachingAudio,cacheDir} from '../services/tencent-speech.mjs';
const dir='scene-preview/assets/avatar/audio';
const prompts={
 coach_apple:'嘴张开，舌头靠前。前面重，后面轻。听一遍，再试一次。',
 coach_banana:'三个音节，中间读重，两端读轻。听完整的，再试一次。',
 coach_want:'先收圆嘴唇，再打开。结尾不要加元音。听一遍，再试。',
 coach_eat:'嘴角展开，结尾短促收住。只有一个音节。先听，再试。',
 coach_red:'舌尖不要碰上腭，留意最后的辅音。先听，再试一次。',
 coach_i:'嘴从张开滑向较小的口形。一口气连起来。先听，再试。',
 coach_a:'先单独练这个短词，再放回句子里轻读。先听，再试。',
 coach_an:'这个短词读轻一点，自然接到后面的单词。先听，再试。',
 coach_to:'和后面的动作自然连起来，不要逐词停顿。先听，再试。',
 coach_sentence:'小段读好了。现在放回整句，听完整句子，再一口气说。',

};
const manifest={};
for(const [key,text]of Object.entries(prompts)){
 const source=await teachingAudio(text,{voice:403008,language:'zh'});
 fs.copyFileSync(path.join(cacheDir,source.key+'.wav'),path.join(dir,key+'.wav'));
 manifest[key]={text,voice:403008,bundled:true,duration:source.duration,cues:source.cues,sourceKey:source.key};
 fs.writeFileSync(path.join(dir,'coach-prompts.json'),JSON.stringify(manifest,null,2)+'\n');
 console.log(key+' ready');
}
