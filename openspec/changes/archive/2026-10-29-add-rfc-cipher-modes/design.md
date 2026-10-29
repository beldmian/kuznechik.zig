## Decisions

- Keep cipher-mode code in generic factories instantiated with the existing Cipher type, avoiding import cycles and retaining independent RFC tests using AES adapters where RFC 8645 provides AES-only examples.
- Expose allocation-free in-place byte APIs that accept unaligned buffers. Streaming contexts preserve unused keystream and feedback across calls.
- Raw ECB/CBC APIs require complete blocks and do not choose an implicit padding scheme. IV and counter formats follow the documented construction.
- Validate parameter/length/counter limits before modifying data. Authenticated decryption verifies the tag before releasing plaintext; failures preserve the caller's ciphertext buffer.
- Batch independent counter encryptions and block decryptions through encryptBlocks/decryptBlocks; serial feedback operations retain their required dependency.
- Keep mode primitives separate from TLS/IKE protocol framing, handshake, signature, and hash-based KDF implementations.
- Protocol cipher-profile helpers accept already-derived per-record/leaf keys;
  they implement RFC nonce formatting, tag policy and cipher limits without
  claiming TLSTREE/KTREE, handshake or complete packet-stack implementations.
- Add measured optimizations after known-answer and negative tests pass, recording the actual backend, target, and message lengths.
