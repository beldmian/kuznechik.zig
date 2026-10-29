const fs=require('fs'),c=require('crypto');let cases=[];
let counter=0;const bytes=n=>{let b=Buffer.alloc(n);for(let i=0;i<n;){let h=c.createHash('sha256').update('review-sol-'+counter++).digest();let k=Math.min(32,n-i);h.copy(b,i,0,k);i+=k;}return b;};
for(let tag=1;tag<=16;tag++)for(const len of [2,14,18,47,79,1010,1042,2049,5009]) {
 let key=bytes(32),nonce=bytes(1+((tag+len)%15)),aad=bytes([2,14,18,63,79,1040,1042,2048,5007][cases.length%9]),plain=bytes(len);
 let ctx=c.createCipheriv('aes-256-ocb',key,nonce,{authTagLength:tag});ctx.setAAD(aad,{plaintextLength:len});let cipher=Buffer.concat([ctx.update(plain),ctx.final()]);
 cases.push(Object.fromEntries(Object.entries({key,nonce,aad,plain,cipher,tag:ctx.getAuthTag()}).map(([k,v])=>[k,v.toString('hex')])));
}
fs.writeFileSync(__dirname+'/new-ocb.json',JSON.stringify(cases));console.log('new OpenSSL OCB cases:',cases.length);
