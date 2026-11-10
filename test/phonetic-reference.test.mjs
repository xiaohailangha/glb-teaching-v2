import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {PhoneticReferences} from '../services/phonetic-reference.mjs';
test('every existing independent IPA recording is served with original bytes and complete combinations',()=>{
 const references=new PhoneticReferences();
 references.get('æ');
 for(const symbol of Object.keys(references.index.symbols)){
  const asset=references.get(symbol),bytes=Buffer.from(asset.inlineAudio,'base64');
  assert.equal(bytes.length,asset.size);
  assert.equal(crypto.createHash('sha256').update(bytes).digest('hex'),asset.sha256);
  assert.equal(bytes.toString('ascii',0,4),'RIFF');
  assert.equal(asset.voice,'phonetic-reference');
  assert.equal(asset.symbol,symbol);
 }
 assert.throws(()=>references.get('../../secret'),{status:404});
 assert.throws(()=>references.get('tʃ'),{status:404});
 assert.notEqual(references.get('aɪ').id,references.get('ɪ').id);
});
