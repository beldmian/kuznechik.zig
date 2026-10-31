# kuznechik.zig

A fast implementation of the Kuznechik (GOST R 34.12-2015) block cipher in Zig. Kuznechik is a symmetric block cipher with a block size of 128 bits and a key length of 256 bits, standardized as GOST R 34.12-2015.

The investigation is closed after its final test. See the [research archive](docs/performance/README.md),
[current performance guide](docs/PERFORMANCE.md), [validation](docs/validation/README.md)
and [open issues](docs/OPEN-WORK.md).

## Features

- Pure Zig implementation
- Optimized using precomputed lookup tables
- Includes both encryption and decryption
- In-place independent-block batches with portable and AVX-512/GFNI kernels
- Performance benchmarks

## Usage

### Basic Example

```zig
const kuznechik = @import("kuznechik");

// Initialize cipher with 256-bit key
var key = kuznechik.key{
    0x88, 0x99, 0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff,
    0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77,
    0xfe, 0xdc, 0xba, 0x98, 0x76, 0x54, 0x32, 0x10,
    0x01, 0x23, 0x45, 0x67, 0x89, 0xab, 0xcd, 0xef,
};

var cipher = kuznechik.Cipher.init(key);

// Create a 128-bit block
var block = kuznechik.block{
    0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x00,
    0xff, 0xee, 0xdd, 0xcc, 0xbb, 0xaa, 0x99, 0x88,
};

// Encrypt
cipher.encrypt(&block);

// Decrypt
cipher.decrypt(&block);
```

For independent block operations, use `cipher.encryptBlocks(blocks[0..])` and
`cipher.decryptBlocks(blocks[0..])` with a mutable array of `kuznechik.block`.
Both accept empty slices and arbitrary lengths with 16-byte alignment. The
batch methods process raw blocks; the caller supplies the cipher mode.

### Cipher modes

The allocation-free `modes` namespace accepts mutable byte slices, including
unaligned buffers. Stateful contexts preserve partial keystream across updates:

```zig
var ctr = kuznechik.modes.Ctr.init(cipher, nonce8);
try ctr.xor(data); // The same operation encrypts and decrypts.

const tag = try kuznechik.modes.Gcm.seal(&cipher, nonce12, associated_data, data);
try kuznechik.modes.Gcm.open(&cipher, nonce12, associated_data, data, tag);
```

Use a unique nonce for each message under the same key. Continue the same stream
context across fragments rather than resetting its counter.

- `ecbEncrypt` / `ecbDecrypt` and `Cbc.encrypt` / `decrypt` require complete
  16-byte blocks and add no padding. CBC uses a 16-byte IV by default.
- `Ctr.xor` uses an 8-byte nonce and a big-endian 64-bit counter starting at zero.
  `CtrWithCounter(bits)` supports RFC 8645 counters of 32–96 bits in byte steps.
- `Cfb.encrypt` / `decrypt` use full-block feedback; `Ofb.xor` supplies a symmetric
  stream operation. `CbcWithIv`, `CfbWithIv`, and `OfbWithIv` accept an IV length
  expressed as a positive number of blocks.
- `Cmac.init`, `update`, `final`, and `verify` implement CMAC/OMAC authentication.
- `Gcm` uses a 12-byte nonce, a 32-bit counter, and the RFC 8645 message bounds.
  `GcmWithCounter(bits)` supports 32–64 counter bits. Full tags are 16 bytes;
  detached APIs also support the standard 4, 8, and 12–16-byte tag sizes.
- `Ccm` uses a 12-byte nonce and supports payloads smaller than 16 MiB.
  `CcmWithLength(L)` selects L=2–8 length bytes and a nonce of 15-L bytes.
  Detached CCM tags support every even byte length from 4 through 16.
- `Mgm` uses a 16-byte nonce with its top bit clear. It supports full 16-byte
  tags and detached 4–16-byte tags, including authentication-only messages.
- `Ocb` supports nonce slices of 0–15 bytes and a full tag. `OcbWithTag(bytes)`
  fixes a 1–16-byte tag in the type; keep one tag policy per key.
- `CtrAcpkm`, `GcmAcpkm`, and the five `*AcpkmMaster` modes implement every
  RFC 8645 internal mode. Section and master-lifetime sizes are explicit byte
  counts; see [API signatures and bounds](docs/MODES.md).
- `KExp15`, `TlsCtrOmac`, and `CtrAcpkmOmac` implement the RFC 9189/9337 cipher
  compositions with separate caller-derived ENC/MAC keys and encrypted tags.
- `Tls13MgmL`, `Tls13MgmS`, `EspMgmKtree`, `EspMgmMacKtree`, and `IkeMgmKtree`
  implement the RFC 9367/9227 cipher profiles with caller-derived record/leaf
  keys. [Profile APIs and dependencies](docs/mgm-profiles.md) specify metadata,
  nonce formation, fixed tags and limits; protocol state and hash-based KDFs
  remain external. `Mgm.sealParts` / `openParts` accept multipart AAD.

Authenticated decryption verifies the tag before modifying the ciphertext buffer.
GCM, CCM, and MGM reject overlapping AAD, payload, and detached output-tag buffers before writes.
OCB and the compositions also reject writable aliases with key storage. See
[mode APIs](docs/MODES.md) and [RFC coverage and profile dependencies](docs/RFC-MODES.md).

### Building

```bash
zig build
```

Validated with Zig 0.15.1. For optimized code targeting the build machine:

```bash
zig build -Doptimize=ReleaseFast -Dcpu=native
```

Kernel selection happens at compile time. Use `-Dcpu=baseline` for portable
binaries; a native build requires the target machine's enabled CPU features.

### Running Tests

```bash
zig build test
```

### Running Benchmarks

```bash
zig build bench -Doptimize=ReleaseFast -- --api both --seed 123
```

Width 1 measures a dependent chain. Larger widths measure independent blocks;
`--api bulk` exercises the batch methods. JSONL output includes raw samples,
median/minimum nanoseconds per block, throughput, CPU features, and checksums.

```bash
zig build build_bench -Doptimize=ReleaseFast
taskset -c 0 zig-out/bin/benchmark --api both --seed 123 2> candidate.jsonl
python3 scripts/perf-compare.py baseline.jsonl candidate.jsonl
```

### Fuzz harnesses

Build the existing harness executables and run their deterministic smoke checks:

```bash
zig build fuzz-build
zig build fuzz-test
```

The standalone runners accept AFL input on stdin; `fuzz-test` remains a smoke
check, not a coverage measurement. See [fuzzing status and build targets](docs/FUZZING.md)
for the short uninstrumented campaign and its limits.

## Performance

Single-block kernels use precomputed substitution/linear tables, with scheduling
tuned separately for measured Zen 5 and Broadwell targets. Independent batches
interleave portable table operations or use AVX-512 VBMI/GFNI instructions when
the compilation target enables them. The 64-block kernel transposes bytes and
evaluates the linear recurrence with GFNI affine maps in Kuznechik's field.

See [performance measurements and reproduction](docs/PERFORMANCE.md) for the
Boat VM comparisons, correctness checks, rejected hypotheses, and measurement
limits. The retained table paths and key expansion use secret-dependent lookups;
these optimizations do not establish a constant-time cipher API.

## Algorithm Details

Kuznechik is a symmetric block cipher that operates on 128-bit blocks using a 256-bit key. The key schedule generates ten round keys. Encryption applies nine rounds of
key XOR, substitution and the linear transformation, followed by the final key XOR.

## References

- [RFC 7801 - GOST R 34.12-2015](https://www.rfc-editor.org/rfc/rfc7801.html)
- [Implementation of «Kuznyechik» cipher using vector instructions](https://www.researchgate.net/publication/346964920_Implementation_of_Kuznyechik_cipher_using_vector_instructions)
## License

MIT License - see the [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Follow-up work

See [tracked issues](docs/OPEN-WORK.md) for remaining performance, validation,
fuzzing and API work.

## Author

[beldmian](https://github.com/beldmian)
