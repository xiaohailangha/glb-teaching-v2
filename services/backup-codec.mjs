import crypto from 'node:crypto';
const magic=Buffer.from('SNOWBK01');
export function sealBackup(payload,key){
 if(key.length!==32)throw Error('Backup encryption key must contain 32 bytes');
 const iv=crypto.randomBytes(12),cipher=crypto.createCipheriv('aes-256-gcm',key,iv);
 cipher.setAAD(magic);const data=Buffer.concat([cipher.update(payload),cipher.final()]);
 return Buffer.concat([magic,iv,cipher.getAuthTag(),data]);
}
export function openBackup(data,key){
 if(data.length<36||!data.subarray(0,8).equals(magic))throw Error('Invalid backup format');
 const decipher=crypto.createDecipheriv('aes-256-gcm',key,data.subarray(8,20));decipher.setAAD(magic);decipher.setAuthTag(data.subarray(20,36));
 return Buffer.concat([decipher.update(data.subarray(36)),decipher.final()]);
}
