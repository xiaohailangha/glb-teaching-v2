import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {projectRoot} from './storage-paths.mjs';
const hash=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
export class PhoneticReferences {
 constructor(directory=path.join(projectRoot,'data/phonetic-reference')){this.directory=directory;this.cache=new Map();}
 get(symbol){
  if(!this.index){const bytes=fs.readFileSync(path.join(this.directory,'index.json'));this.index=JSON.parse(bytes);this.revision=hash(bytes);if(this.index.schema!=='snow-speaks.phonetic-reference/1')throw Error('音标资料无效');}
  const id=Object.hasOwn(this.index.symbols,symbol)?this.index.symbols[symbol]:null,a=this.index.assets[id];
  if(!a||!/^phoneme_[a-z]+\.wav$/.test(a.file))throw Object.assign(Error('当前音标暂无独立录音'),{status:404});
  if(!this.cache.has(id)){const bytes=fs.readFileSync(path.join(this.directory,a.file));if(bytes.length!==a.size||hash(bytes)!==a.sha256)throw Error('音标声音校验失败');this.cache.set(id,bytes.toString('base64'));}
  return {kind:'phonetic-reference',voice:'phonetic-reference',id,symbol,referenceRevision:this.revision,sha256:a.sha256,size:a.size,cues:a.cues,inlineAudio:this.cache.get(id)};
 }
}
