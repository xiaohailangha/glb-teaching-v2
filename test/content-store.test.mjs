import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import crypto from 'node:crypto';
import {ContentStore,validateRelease,previewToken,validPreview} from '../services/content-store.mjs';
import {sealBackup,openBackup} from '../services/backup-codec.mjs';
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
function release(label){const catalog={release:label,courses:[{id:'adult-fruit-v2',status:'published',asset:'fruit'}]},assets=[{path:'assets/avatar/courses/fruit.json',size:2,sha256:hash('{}')}],id=hash(JSON.stringify({catalog,assets}));return {schema:1,id,created:Date.now(),catalog,assets:assets.map(a=>({...a,key:`courses/releases/${id}/${a.path}`}))};}
test('publication is explicit, compare-and-swap protected, and old sessions remain pinned',async()=>{
 const directory=fs.mkdtempSync(path.join(os.tmpdir(),'snow-content-test-'));try{
 const store=new ContentStore({directory,sign:async r=>r.assets.map(a=>({...a,url:'https://example.test/'+a.key}))}),a=release('one'),b=release('two');
 store.stage(a);store.stage(b);await assert.rejects(store.manifest(a.id),{status:404});store.activate(a.id,null);assert.throws(()=>store.activate(b.id,null),{status:409});store.activate(b.id,a.id);assert.equal((await store.manifest(a.id)).id,a.id);assert.equal(store.catalog().release,'two');store.activate(a.id,b.id);assert.equal(store.catalog().release,'one');
 }finally{fs.rmSync(directory,{recursive:true,force:true});}
});
test('release digest, traversal and preview token integrity are enforced',()=>{const r=release('one');r.catalog.release='tampered';assert.throws(()=>validateRelease(r));const p=release('one');p.assets[0].path='../secret';assert.throws(()=>validateRelease(p));const t=previewToken('secret',1000);assert.ok(validPreview(t,'secret',1001));assert.equal(validPreview(t,'wrong',1001),false);assert.equal(validPreview(t,'secret',301001),false);});
test('encrypted backups reject wrong keys and ciphertext modification',()=>{const key=crypto.randomBytes(32),payload=Buffer.from('database snapshot'),sealed=sealBackup(payload,key);assert.deepEqual(openBackup(sealed,key),payload);assert.throws(()=>openBackup(sealed,crypto.randomBytes(32)));sealed[sealed.length-1]^=1;assert.throws(()=>openBackup(sealed,key));});
