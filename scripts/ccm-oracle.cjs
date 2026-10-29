// Development-only independent AES-CCM fixtures (Node/OpenSSL, no Zig code).
const fs = require('node:fs');
const crypto = require('node:crypto');
const key = Buffer.from('00112233445566778899aabbccddeeff', 'hex');
const lengths = [0, 1, 15, 16, 17, 1023, 1024, 1025];
const aadLengths = [0, 1, 15, 16, 17, 33, 65279, 65280, 65535];
const cases = [];
for (let length_bytes = 2; length_bytes <= 8; length_bytes++) {
  for (let tag_length = 4; tag_length <= 16; tag_length += 2) {
    const index = cases.length;
    const plain_length = lengths[index % lengths.length];
    const aad_length = aadLengths[index % aadLengths.length];
    const nonce = Buffer.from(Array.from({length: 15 - length_bytes}, (_, i) => (i * 7 + length_bytes * 13 + tag_length * 3) & 255));
    const data = Buffer.from(Array.from({length: plain_length}, (_, i) => (i * 17 + index) & 255));
    const aad = Buffer.from(Array.from({length: aad_length}, (_, i) => (i * 29 + index * 3) & 255));
    const cipher = crypto.createCipheriv('aes-128-ccm', key, nonce, {authTagLength: tag_length});
    cipher.setAAD(aad, {plaintextLength: data.length});
    const ciphertext = Buffer.concat([cipher.update(data), cipher.final()]);
    cases.push({index, length_bytes, tag_length, plain_length, aad_length, ciphertext: ciphertext.toString('hex'), tag: cipher.getAuthTag().toString('hex')});
  }
}
fs.writeFileSync(process.argv[2] || 'src/modes/ccm_oracle.json', JSON.stringify({node: process.version, openssl: process.versions.openssl, key: key.toString('hex'), cases}, null, 2) + '\n');
