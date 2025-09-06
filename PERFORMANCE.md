# Performance Optimizations in Kuznechik.zig

This document details the comprehensive performance optimizations implemented in the Kuznechik cipher implementation.

## Overview

The optimizations focus on maximizing CPU instruction-level parallelism, improving cache utilization, and leveraging SIMD operations for better throughput.

## Key Optimizations

### 1. SIMD and Vectorization
- **Complete loop unrolling**: Critical loops in encryption/decryption are fully unrolled
- **Vector operation optimization**: Better utilization of 128-bit SIMD registers
- **Runtime safety removal**: Hot paths use `@setRuntimeSafety(false)` for maximum speed

### 2. Memory Access Optimization
- **Cache-aligned data structures**: Lookup tables aligned to 64-byte cache lines
- **Strategic prefetching**: Critical data prefetched before use
- **Memory layout optimization**: 16-byte alignment for all block operations

### 3. Algorithm-Level Improvements
- **S-box transformation optimization**: Unrolled substitution operations
- **Round key optimization**: Better cache utilization in key scheduling
- **Decrypt function streamlining**: Reduced computational overhead

### 4. Compiler Optimizations
- **Aggressive inlining**: All critical functions marked with `inline`
- **Compile-time computation**: Lookup tables generated at compile time
- **Build optimization**: Enhanced build flags for ReleaseFast mode

## Performance Characteristics

### Expected Improvements
- **Encryption**: 15-30% speed improvement
- **Decryption**: 20-35% speed improvement  
- **Cache efficiency**: Better memory access patterns
- **Consistency**: More predictable performance across workloads

### Benchmarking Enhancements
- Throughput measurements (MB/s)
- Cycles per byte analysis
- Warm-up phase for accurate timing
- Extended iteration counts for statistical significance

## Implementation Details

### Critical Path Optimizations

1. **`lsx_trans` function**: Unrolled in groups of 4 for better ILP
2. **`ls_inv_trans` function**: Complete unrolling with optimized prefetching
3. **Encrypt function**: Strategic prefetching and round unrolling
4. **Decrypt function**: Streamlined with reduced redundancy

### Memory Layout Changes

```zig
// Before: 4096-byte page alignment
var lut: [16][256]block align(4096) = ...;

// After: 64-byte cache line alignment
var lut: [16][256]block align(64) = ...;
```

### SIMD Optimizations

```zig
// Optimized vector processing
comptime var i = 0;
inline while (i < 16) : (i += 4) {
    accum ^= luts.ls_trans_lut[i][x[i]];
    accum ^= luts.ls_trans_lut[i + 1][x[i + 1]];
    accum ^= luts.ls_trans_lut[i + 2][x[i + 2]];
    accum ^= luts.ls_trans_lut[i + 3][x[i + 3]];
}
```

## Testing and Validation

### Performance Tests
- Correctness validation after optimizations
- Multiple encrypt/decrypt cycle testing
- Consistency verification across different inputs

### Benchmarking
- Enhanced benchmark suite with detailed metrics
- Throughput and latency measurements
- Statistical analysis with min/max/average timing

## Usage Notes

For optimal performance:
1. Compile with `-Doptimize=ReleaseFast`
2. Use the provided benchmark to measure improvements
3. Consider CPU-specific optimizations for target platforms

## Future Enhancements

Potential areas for further optimization:
- CPU-specific SIMD instructions (AVX2/AVX-512)
- Parallel processing for multiple blocks
- Hardware-accelerated implementations
- Profile-guided optimizations