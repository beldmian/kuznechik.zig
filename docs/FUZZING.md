# Fuzzing Guide

This guide covers comprehensive usage of AFL++ for fuzzing the Kuznechik cipher implementation.

## Table of Contents

- [Overview](#overview)
- [Installation](#installation)
- [Building Fuzzers](#building-fuzzers)
- [Running AFL++](#running-afl)
- [AFL++ Modes](#afl-modes)
- [Understanding Results](#understanding-results)
- [Advanced Usage](#advanced-usage)
- [Troubleshooting](#troubleshooting)

## Overview

This project includes three fuzzing harnesses that test different properties of the Kuznechik cipher:

1. **roundtrip** - Tests encryption/decryption round-trip property
2. **key_schedule** - Tests key schedule generation and validation
3. **ls_roundtrip** - Tests LS (Linear Substitution) transformation round-trip property

Each harness is designed to be used with AFL++ to discover edge cases, bugs, and potential security vulnerabilities.

## Installation

### macOS

```bash
brew install afl++
```

### Linux (Debian/Ubuntu)

```bash
sudo apt-get install afl++
```

### Linux (Fedora/RHEL)

```bash
sudo dnf install afl++
```

### From Source (for QEMU/FRIDA modes)

If you need QEMU or FRIDA mode (recommended for Zig), build from source:

```bash
git clone https://github.com/AFLplusplus/AFLplusplus
cd AFLplusplus
make all
make install
```

See [AFL++ Documentation](https://github.com/AFLplusplus/AFLplusplus) for details.

### Verify Installation

```bash
afl-fuzz --version
```

## Building Fuzzers

### Build All Fuzzers

```bash
zig build fuzz-build
```

### Build Individual Fuzzer

```bash
# Round-trip encryption/decryption fuzzer
zig build fuzz-round-trip

# Key schedule validation fuzzer
zig build fuzz-key-schedule

# LS round-trip fuzzer
zig build fuzz-ls-roundtrip
```

### Validate Fuzzers (Standalone Testing)

```bash
zig build fuzz-test
```

This runs each fuzzer with its test corpus to verify they work correctly.

## Running AFL++

### Quick Start

The simplest way to start fuzzing:

```bash
# Build the fuzzer
zig build fuzz-ls-roundtrip

# Run AFL++ in dumb mode (works everywhere)
afl-fuzz -n -i test/fuzz/corpus/ls_roundtrip -o test/fuzz/output/ls_roundtrip -- ./zig-out/bin/ls_roundtrip
```

### Basic Command Structure

```bash
afl-fuzz [OPTIONS] -i <input_corpus> -o <output_dir> -- <fuzzer_binary>
```

### Common Options

- `-i <dir>`: Input corpus directory (seed inputs)
- `-o <dir>`: Output directory for results
- `--`: Separator before target command
- `-n`: Dumb mode (no instrumentation)
- `-Q`: QEMU mode (binary instrumentation)
- `-O`: FRIDA mode (dynamic instrumentation)
- `-t <ms>`: Timeout in milliseconds (default: 1000)
- `-m <mem>`: Memory limit in MB (default: none)
- `-d`: Quick & dirty mode (skips deterministic steps)
- `-j <n>`: Number of parallel jobs

## AFL++ Modes

### Why Multiple Modes?

Zig uses its own compiler backend which doesn't support AFL++'s compile-time instrumentation. Different modes provide different trade-offs:

### 1. Dumb Mode (`-n`)

**Pros:**
- Works with any binary
- No setup required
- Fast execution

**Cons:**
- No coverage guidance
- Less effective at finding bugs
- Random mutation only

**Use Case:** Quick smoke testing, when you can't use other modes

```bash
afl-fuzz -n -i test/fuzz/corpus/ls_roundtrip -o test/fuzz/output/ls_roundtrip -- ./zig-out/bin/ls_roundtrip
```

### 2. QEMU Mode (`-Q`)

**Pros:**
- Binary instrumentation (no recompilation needed)
- Coverage guidance
- Good performance

**Cons:**
- Requires building AFL++ from source
- Slightly slower than compile-time instrumentation

**Use Case:** Recommended for Zig programs

```bash
afl-fuzz -Q -i test/fuzz/corpus/ls_roundtrip -o test/fuzz/output/ls_roundtrip -- ./zig-out/bin/ls_roundtrip
```

### 3. FRIDA Mode (`-O`)

**Pros:**
- Dynamic instrumentation
- Good coverage
- Works on closed-source binaries

**Cons:**
- Requires FRIDA installation
- More complex setup

**Use Case:** When QEMU mode is not available

```bash
# Install FRIDA first
pip install frida-tools

# Run with FRIDA mode
afl-fuzz -O -i test/fuzz/corpus/ls_roundtrip -o test/fuzz/output/ls_roundtrip -- ./zig-out/bin/ls_roundtrip
```

## Understanding Results

### Output Directory Structure

```
test/fuzz/output/ls_roundtrip/
├── default/                    # Default fuzzer instance
│   ├── crashes/               # Inputs that triggered crashes
│   ├── hangs/                 # Inputs that caused timeouts
│   ├── queue/                 # Interesting inputs discovered
│   ├── fuzzer_stats           # Statistics file
│   ├── plot_data              # Coverage plotting data
│   └── fuzz_bitmap            # Coverage bitmap
├── fuzzer_stats               # Human-readable statistics
└── sync/                      # Multi-instance synchronization
```

### Reading Statistics

The `fuzzer_stats` file contains real-time statistics:

```
run_time : 3600              # Total run time in seconds
execs_per_sec : 1234         # Executions per second
execs_done : 4444444         # Total executions
exec_timeout : 0             # Number of timeouts
unique_crashes : 0           # Unique crashes found
saved_crashes : 0            # Crashes saved to disk
saved_hangs : 0              # Hangs saved to disk
max_depth : 12               # Maximum path depth
cur_path : 1234              # Current queue size
pending_total : 56           # Total pending items
pending_favs : 12            # Pending favorites
map_size : 1234              # Coverage bitmap size
```

### Key Metrics

- **execs_per_sec**: Higher is better (aim for >1000)
- **unique_crashes**: Should be 0 (non-zero = bugs found!)
- **cur_path**: Number of unique code paths discovered
- **saved_crashes**: Crashes saved for reproduction

### Reproducing Crashes

To reproduce a crash:

```bash
# Run the fuzzer with the crash file as input
./zig-out/bin/ls_roundtrip < test/fuzz/output/ls_roundtrip/default/crashes/id:000000,sig:06,src:000123,op:havoc,rep:16
```

### Analyzing Crashes

Crash filename format: `id:XXXXXX,sig:XX,src:XXXXXX,op:XXXX,rep:X`

- `sig`: Signal number (06 = SIGABRT, 11 = SIGSEGV, etc.)
- `src`: Source queue item
- `op`: Operation that caused the crash
- `rep`: Reproduction count

## Advanced Usage

### Parallel Fuzzing

Run multiple AFL++ instances in parallel for better coverage:

```bash
# Main instance (master)
afl-fuzz -M fuzzer01 -Q -i test/fuzz/corpus/ls_roundtrip -o test/fuzz/output/ls_roundtrip -- ./zig-out/bin/ls_roundtrip &

# Secondary instances
afl-fuzz -S fuzzer02 -Q -i test/fuzz/corpus/ls_roundtrip -o test/fuzz/output/ls_roundtrip -- ./zig-out/bin/ls_roundtrip &
afl-fuzz -S fuzzer03 -Q -i test/fuzz/corpus/ls_roundtrip -o test/fuzz/output/ls_roundtrip -- ./zig-out/bin/ls_roundtrip &
```

### Dictionary Mode

Add a dictionary for smarter mutations:

```bash
afl-fuzz -Q -x test/fuzz/dictionaries/bytes.dict -i test/fuzz/corpus/ls_roundtrip -o test/fuzz/output/ls_roundtrip -- ./zig-out/bin/ls_roundtrip
```

### Persistent Mode

For faster execution with custom harness:

```bash
# Your harness must define __AFL_LOOP(N)
afl-fuzz -Q -i test/fuzz/corpus/ls_roundtrip -o test/fuzz/output/ls_roundtrip -- ./zig-out/bin/ls_roundtrip
```

### Crash Exploration Mode

Focus on existing crashes:

```bash
afl-fuzz -Q -C -i test/fuzz/output/ls_roundtrip/default/crashes -o test/fuzz/output/ls_roundtrip_crash -- ./zig-out/bin/ls_roundtrip
```

### Memory Limit

Set memory limit (in MB):

```bash
afl-fuzz -Q -m 256 -i test/fuzz/corpus/ls_roundtrip -o test/fuzz/output/ls_roundtrip -- ./zig-out/bin/ls_roundtrip
```

## Troubleshooting

### "No instrumentation detected"

**Problem:** AFL++ requires compile-time instrumentation but Zig doesn't support it.

**Solution:** Use QEMU mode (`-Q`) or dumb mode (`-n`):

```bash
afl-fuzz -Q -i test/fuzz/corpus/ls_roundtrip -o test/fuzz/output/ls_roundtrip -- ./zig-out/bin/ls_roundtrip
```

### "Program 'afl-qemu-trace' not found"

**Problem:** QEMU mode not installed (common with Homebrew AFL++).

**Solution 1:** Use dumb mode instead:

```bash
afl-fuzz -n -i test/fuzz/corpus/ls_roundtrip -o test/fuzz/output/ls_roundtrip -- ./zig-out/bin/ls_roundtrip
```

**Solution 2:** Build AFL++ from source with QEMU support:

```bash
git clone https://github.com/AFLplusplus/AFLplusplus
cd AFLplusplus
make all
sudo make install
```

### Slow Execution Speed

**Problem:** execs_per_sec is very low (<100).

**Solutions:**
- Use dumb mode (`-n`) for faster execution
- Increase timeout: `-t 5000`
- Disable screen updates: AFL_NO_UI=1
- Check system resources

### Out of Memory

**Problem:** Fuzzer crashes due to memory usage.

**Solution:** Set memory limit:

```bash
afl-fuzz -Q -m 512 -i test/fuzz/corpus/ls_roundtrip -o test/fuzz/output/ls_roundtrip -- ./zig-out/bin/ls_roundtrip
```

### Permission Denied on Output Directory

**Problem:** Can't write to output directory.

**Solution:** Create directory with proper permissions:

```bash
mkdir -p test/fuzz/output/ls_roundtrip
chmod 755 test/fuzz/output/ls_roundtrip
```

## Best Practices

1. **Start with corpus**: Use known test vectors as seed corpus
2. **Run continuously**: Let AFL++ run for hours or days
3. **Monitor regularly**: Check stats for unusual behavior
4. **Reproduce crashes**: Save and analyze any crashes found
5. **Update code**: Fix bugs and re-fuzz
6. **Use multiple modes**: Combine dumb, QEMU, and FRIDA modes
7. **Parallel fuzzing**: Run multiple instances for better coverage

## Resources

- [AFL++ Documentation](https://github.com/AFLplusplus/AFLplusplus)
- [AFL++ Quick Start Guide](https://github.com/AFLplusplus/AFLplusplus/blob/stable/docs/fuzzing_in_depth.md)
- [Fuzzing Best Practices](https://github.com/google/fuzzing/blob/master/docs/best-practices.md)
