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
zig build bench
```

### Fuzzing

This project includes fuzzing infrastructure using AFL++ to continuously test cipher properties and discover edge cases.

#### Installation

**macOS:**
```bash
brew install afl++
```

**Linux (Debian/Ubuntu):**
```bash
sudo apt-get install afl++
```

**Linux (Fedora/RHEL):**
```bash
sudo dnf install afl++
```

Verify your installation:
```bash
afl-fuzz --version
```

#### Building Fuzzers

Build a specific fuzzer:
```bash
zig build fuzz-ls-roundtrip
```

Build all fuzzers:
```bash
zig build fuzz-build
```

#### Running Fuzzers

Run a specific fuzzer with AFL++:
```bash
# Build the fuzzer first
zig build fuzz-ls-roundtrip

# Run AFL++ with the corpus
afl-fuzz -i test/fuzz/corpus/transformations -o test/fuzz/output/transformations -- ./zig-out/bin/ls_roundtrip
```

AFL++ options:
- `-i`: Input corpus directory (seed inputs)
- `-o`: Output directory for results
- `--`: Separator before the fuzzer executable

#### Understanding Results

AFL++ creates an output directory with the following structure:

```
test/fuzz/output/transformations/
├── crashes/          # Inputs that triggered crashes
├── hangs/            # Inputs that caused timeouts
├── queue/            # Interesting inputs discovered
└── fuzzer_stats/     # Statistics and progress
```

**Crashes:**
- Check `crashes/` for files that triggered assertion failures or panics
- Each crash file contains the input that reproduces the issue
- Run the fuzzer directly with a crash file to reproduce: `./zig-out/bin/ls_roundtrip < crashes/id:000000...`

**Hangs:**
- Inputs in `hangs/` exceeded the timeout threshold (default: 1 second)
- May indicate infinite loops or performance issues
- Adjust timeout with AFL++'s `-t` option

**Statistics:**
- Monitor `fuzzer_stats` for execution speed, coverage, and discovered paths
- `execs_per_sec`: Executions per second (higher is better)
- `unique_crashes`: Total unique crashes found
- `saved_crashes`: Crashes saved to disk

#### Testing Fuzzers Standalone

Validate that fuzz harnesses work correctly without AFL++:
```bash
zig build fuzz-test
```

## Performance

The implementation is optimized using precomputed lookup tables for the S-box, inverse S-box, and linear transformations. Benchmark results on Apple M2:

```
Running benchmark: Encrypt Benchmark (65535 iterations)
Encrypt Benchmark:
  Iterations: 65535
  Total time: 5056195 ns
  Average time: 77 ns
  Min time: 0 ns
  Max time: 18375 ns

Running benchmark: Decrypt Benchmark (65535 iterations)
Decrypt Benchmark:
  Iterations: 65535
  Total time: 5698981 ns
  Average time: 86 ns
  Min time: 0 ns
  Max time: 10167 ns
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

- [ ] Add more fuzzing harnesses (encryption/decryption round-trip, key schedule)
- [ ] Improve performance further
- [ ] Add cipher operation modes (CTR, CBC, GCM, etc.)

## Author

[beldmian](https://github.com/beldmian)
