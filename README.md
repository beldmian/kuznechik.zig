# kuznechik.zig

A fast implementation of the Kuznechik (GOST R 34.12-2015) block cipher in Zig. Kuznechik is a symmetric block cipher with a block size of 128 bits and a key length of 256 bits, standardized as GOST R 34.12-2015.

## Features

- Pure Zig implementation
- Optimized using precomputed lookup tables
- Includes both encryption and decryption
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

### Building

```bash
zig build
```

*To achieve better performance, compile with `-Doptimize=ReleaseFast`*

### Running Tests

```bash
zig build test
```

### Running Benchmarks

```bash
zig build benchmark
```

## Performance

The implementation is optimized using precomputed lookup tables for the S-box, inverse S-box, and linear transformations. Benchmark results on Apple M2:

```
benchmark              runs     total time     time/run (avg ± σ)     (min ... max)                p75        p99        p995
-----------------------------------------------------------------------------------------------------------------------------
Encrypt Benchmark      65535    4.688ms        71ns ± 18ns            (0ns ... 209ns)              83ns       84ns       84ns
Decrypt Benchmark      65535    5.504ms        84ns ± 65ns            (41ns ... 13.084us)          84ns       125ns      125ns
```


## Algorithm Details

Kuznechik is a symmetric block cipher that operates on 128-bit blocks using a 256-bit key. The encryption process consists of:
- 10 rounds of transformations
- Key schedule generating 10 round keys
- Each round applies:
  - Key addition (XOR)
  - Substitution layer (S-box)
  - Linear transformation (L)

## References

- [RFC 7801 - GOST R 34.12-2015](https://www.rfc-editor.org/rfc/rfc7801.html)
- [Implementation of «Kuznyechik» cipher using vector instructions](https://www.researchgate.net/publication/346964920_Implementation_of_Kuznyechik_cipher_using_vector_instructions)
## License

MIT License - see the [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Future Plans

- [ ] Add fuzzing tests
- [ ] Improve performance further
- [ ] Add cipher operation modes

## Author

[beldmian](https://github.com/beldmian)
