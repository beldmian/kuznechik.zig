#!/usr/bin/env node
// Independent fixtures from Node/OpenSSL OCB, not a reimplementation of RFC7253.
// Run: node scripts/ocb-oracle.cjs > src/modes/ocb_oracle.json
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
for (const bits of [128, 192, 256]) assert(crypto.getCiphers().includes(`aes-${bits}-ocb`));
const sizes = [0, 1, 2, 7, 8, 15, 16, 17, 31, 32, 33, 63, 64, 65, 127, 128, 255, 1008, 1023, 1024, 1025, 1039, 1040, 2047, 2048, 2049];
const pattern = (n, mul, add) => Buffer.from(Array.from({length:n}, (_, i) => (i * mul + add) & 255));
const cases = [];
function add(key_bytes, nonce_length, tag_length, bottom) {
  const index = cases.length;
  const nonce = pattern(nonce_length, 7, index * 3 + tag_length);
  nonce[nonce.length - 1] = (nonce[nonce.length - 1] & 192) | bottom;
  const key = pattern(key_bytes, 11, key_bytes);
  const p = pattern(sizes[index % sizes.length], 17, index);
  const a = pattern(sizes[(index * 7 + 3) % sizes.length], 29, index * 3);
  const enc = crypto.createCipheriv(`aes-${key_bytes * 8}-ocb`, key, nonce, {authTagLength:tag_length});
  enc.setAAD(a);
  const ciphertext = Buffer.concat([enc.update(p), enc.final()]);
  const tag = enc.getAuthTag();
  const dec = crypto.createDecipheriv(`aes-${key_bytes * 8}-ocb`, key, nonce, {authTagLength:tag_length});
  dec.setAAD(a);
  dec.setAuthTag(tag);
  assert.deepEqual(Buffer.concat([dec.update(ciphertext), dec.final()]), p);
  cases.push({index, key_bytes, nonce:nonce.toString('hex'), tag_length, plain_length:p.length, aad_length:a.length, ciphertext:ciphertext.toString('hex'), tag:tag.toString('hex')});
}
for (let nonce = 1; nonce <= 15; nonce++) for (let tag = 1; tag <= 16; tag++) add(16, nonce, tag, cases.length % 64);
for (const key of [24,32]) for (let nonce = 1; nonce <= 15; nonce++) for (const tag of [8,12,16]) add(key, nonce, tag, cases.length % 64);
for (let bottom = 0; bottom < 64; bottom++) add(16, 12, 16, bottom);
process.stdout.write(JSON.stringify({source:'Node crypto / OpenSSL OCB; scripts/ocb-oracle.cjs', node:process.version, openssl:process.versions.openssl, cases}, null, 2) + '\n');
