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

**Quick Links:**
- [Comprehensive Fuzzing Guide](docs/FUZZING.md) - Detailed documentation on AFL++ usage
- [Helper Scripts](#helper-scripts) - Convenient scripts for common fuzzing workflows

#### Available Fuzzers

1. **roundtrip** - Tests encryption/decryption round-trip property
2. **key_schedule** - Tests key schedule generation and validation
3. **ls_roundtrip** - Tests LS (Linear Substitution) transformation round-trip property

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

#### Helper Scripts

Convenience scripts are provided in the `scripts/` directory for common fuzzing workflows:

**Quick Start (Dumb Mode - Works Everywhere):**
```bash
./scripts/fuzz-dumb.sh ls_roundtrip
```

**QEMU Mode (Binary Instrumentation - Recommended):**
```bash
./scripts/fuzz-qemu.sh ls_roundtrip
```

**Parallel Fuzzing (Multiple Instances):**
```bash
./scripts/fuzz-parallel.sh ls_roundtrip dumb 4  # 4 parallel instances
./scripts/fuzz-parallel.sh ls_roundtrip qemu 4  # with QEMU mode
```

**View Statistics:**
```bash
./scripts/fuzz-stats.sh
```

**Reproduce a Crash:**
```bash
./scripts/fuzz-reproduce.sh ls_roundtrip test/fuzz/output/ls_roundtrip_dumb/default/crashes/id:000000,...
```

**Clean Output Directories:**
```bash
./scripts/fuzz-clean.sh
```

**All Scripts:**
- `fuzz-dumb.sh` - Run AFL++ in dumb mode (no instrumentation)
- `fuzz-qemu.sh` - Run AFL++ in QEMU mode (binary instrumentation)
- `fuzz-parallel.sh` - Run multiple AFL++ instances in parallel
- `fuzz-stats.sh` - Display statistics for all fuzzing sessions
- `fuzz-reproduce.sh` - Reproduce crashes found by AFL++
- `fuzz-clean.sh` - Clean up fuzzing output directories

#### Running Fuzzers

**Quick Start with Helper Scripts:**

The easiest way to start fuzzing is using the provided helper scripts:

```bash
# Dumb mode (works everywhere, no setup required)
./scripts/fuzz-dumb.sh ls_roundtrip

# QEMU mode (recommended, requires AFL++ built with QEMU support)
./scripts/fuzz-qemu.sh ls_roundtrip

# Parallel fuzzing (4 instances for better coverage)
./scripts/fuzz-parallel.sh ls_roundtrip dumb 4
```

**Manual AFL++ Usage:**

If you prefer to use AFL++ directly:

**Important Note:** Zig uses its own compiler backend which does not support AFL++'s compile-time instrumentation. To use AFL++ with Zig binaries, you must use one of the following modes:

**Option 1: Dumb Mode (No instrumentation, simplest)**
```bash
# Build the fuzzer first
zig build fuzz-ls-roundtrip

# Run AFL++ in dumb mode (-n flag)
# This mode doesn't use coverage guidance but still provides mutation and crash detection
afl-fuzz -n -i test/fuzz/corpus/ls_roundtrip -o test/fuzz/output/ls_roundtrip -- ./zig-out/bin/ls_roundtrip
```

**Option 2: QEMU Mode (Binary instrumentation, recommended for Zig)**
```bash
# Install AFL++ with QEMU mode (requires building from source)
# See: https://github.com/AFLplusplus/AFLplusplus#qemu-mode

# Run AFL++ with QEMU mode (-Q flag)
afl-fuzz -Q -i test/fuzz/corpus/ls_roundtrip -o test/fuzz/output/ls_roundtrip -- ./zig-out/bin/ls_roundtrip
```

**Option 3: FRIDA Mode (Dynamic instrumentation)**
```bash
# Install FRIDA and AFL++ FRIDA mode
# See: https://github.com/AFLplusplus/AFLplusplus#frida-mode

# Run AFL++ with FRIDA mode (-O flag)
afl-fuzz -O -i test/fuzz/corpus/ls_roundtrip -o test/fuzz/output/ls_roundtrip -- ./zig-out/bin/ls_roundtrip
```

**For more detailed information, see [FUZZING.md](docs/FUZZING.md)**

#### Understanding Results

AFL++ creates an output directory with the following structure:

```
test/fuzz/output/ls_roundtrip/
├── default/
│   ├── crashes/          # Inputs that triggered crashes
│   ├── hangs/            # Inputs that caused timeouts
│   ├── queue/            # Interesting inputs discovered
│   └── fuzzer_stats      # Statistics and progress
```

**Crashes:**
- Check `default/crashes/` for files that triggered assertion failures or panics
- Each crash file contains the input that reproduces the issue
- Run the fuzzer directly with a crash file to reproduce: `./zig-out/bin/ls_roundtrip < default/crashes/id:000000...`

**Hangs:**
- Inputs in `default/hangs/` exceeded the timeout threshold (default: 1 second)
- May indicate infinite loops or performance issues
- Adjust timeout with AFL++'s `-t` option

**Statistics:**
- Monitor `default/fuzzer_stats` for execution speed, coverage, and discovered paths
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

- [x] Add fuzzing harnesses (encryption/decryption round-trip, key schedule, LS transformation)
- [ ] Improve performance further
- [ ] Add cipher operation modes (CTR, CBC, GCM, etc.)

## Author

[beldmian](https://github.com/beldmian)
