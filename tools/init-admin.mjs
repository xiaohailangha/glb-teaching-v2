// One-time private bootstrap; never includes a reusable password in source.
import fs from 'node:fs';
import crypto from 'node:crypto';
const password=process.env.ADMIN_INITIAL_PASSWORD;
if(!password||password.length<6)throw Error('Set ADMIN_INITIAL_PASSWORD with at least 6 characters.');
const salt=crypto.randomBytes(16).toString('hex');
fs.mkdirSync('.secrets',{recursive:true,mode:0o700});
fs.writeFileSync('.secrets/admin-bootstrap.json',JSON.stringify({salt,hash:crypto.scryptSync(password,salt,64).toString('hex')}),{mode:0o600,flag:'wx'});
console.log('Private administrator bootstrap prepared. Existing administrators are never overwritten.');
