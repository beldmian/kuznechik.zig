// Independent AES-128 OCB boundary outputs, whole-ciphertext SHA256 + full tag.
const crypto = require('node:crypto');
const fs = require('node:fs');
const counts = [0,1,2,3,4,7,8,9,15,16,17,31,32,33,63,64,65,127,128,129,255,256,257,511,512,513,1023,1024,1025,2047,2048,2049,4095,4096,4097];
const cases=[];
for (const [i,n] of counts.entries()) {
  for (const [j,tagLength] of [1,8,12,16].entries()) {
    for (let axis=0; axis<2; axis++) {
      const index=cases.length;
      const tail=[0,1,15][(i+j)%3];
      const other=[0,1,15,16,17,7*16,8*16+1,65*16+15][(i+j)%8];
      const p=axis===0?n*16+tail:other;
      const a=axis===1?n*16+tail:other;
      const key=Buffer.from(Array.from({length:16},(_,k)=>(k*11+index*7)&255));
      const nonce=Buffer.from(Array.from({length:1+index%15},(_,k)=>(k*37+index)&255));
      const plain=Buffer.from(Array.from({length:p},(_,k)=>(k*17+index)&255));
      const aad=Buffer.from(Array.from({length:a},(_,k)=>(k*29+index*3)&255));
      const c=crypto.createCipheriv('aes-128-ocb',key,nonce,{authTagLength:tagLength});
      c.setAAD(aad); const encrypted=Buffer.concat([c.update(plain),c.final()]);
      cases.push({index,p,a,tag_length:tagLength,sha256:crypto.createHash('sha256').update(encrypted).digest('hex'),tag:c.getAuthTag().toString('hex')});
    }
  }
}
fs.writeFileSync(process.argv[2],JSON.stringify({source:process.version+' '+process.versions.openssl,cases},null,2)+'\n');
