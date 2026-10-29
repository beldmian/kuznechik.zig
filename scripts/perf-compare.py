#!/usr/bin/env python3
"""Compare two benchmark JSONL files after validating workload equivalence.

Example:
    python3 scripts/perf-compare.py baseline.jsonl candidate.jsonl
    python3 scripts/perf-compare.py baseline.jsonl candidate.jsonl --json

JSONL is emitted on stderr by the benchmark, so capture a run with 2>file.
A missing bulk API is allowed: bulk_available explicitly records the baseline's
single-block fallback. Configuration, workloads and output checksums must match.
"""

import argparse
import itertools
import json
import math
from pathlib import Path
import re
import statistics
import sys

SUPPORTED_WIDTHS = (1, 2, 3, 4, 5, 7, 8, 15, 16, 31, 32, 63, 64, 256)
DEFAULT_WIDTHS = (1, 2, 4, 8, 16, 32, 256)


class InvalidRun(ValueError):
    pass


def require(condition, message):
    if not condition:
        raise InvalidRun(message)


def positive_number(value):
    return type(value) in (int, float) and math.isfinite(value) and value > 0


def load_run(path):
    configs = []
    rows = {}
    with path.open(encoding="utf-8") as source:
        for line_number, line in enumerate(source, 1):
            if not line.strip():
                continue
            try:
                record = json.loads(line)
            except json.JSONDecodeError as error:
                raise InvalidRun(f"{path}:{line_number}: invalid JSON: {error.msg}") from error
            require(isinstance(record, dict), f"{path}:{line_number}: expected a JSON object")
            if record.get("type") == "config":
                configs.append(record)
                continue
            require(record.get("type") == "result", f"{path}:{line_number}: unknown record type")
            operation = record.get("operation")
            api = record.setdefault("api", "single")
            width = record.get("width")
            require(operation in ("encrypt", "decrypt"), f"{path}:{line_number}: invalid operation")
            require(api in ("single", "bulk"), f"{path}:{line_number}: invalid API")
            require(type(width) is int and width in SUPPORTED_WIDTHS, f"{path}:{line_number}: invalid width")
            key = operation, api, width
            require(key not in rows, f"{path}:{line_number}: duplicate workload {key}")
            available = record.setdefault("bulk_available", False)
            require(type(available) is bool, f"{path}:{line_number}: invalid bulk_available")
            rows[key] = record
    require(len(configs) == 1, f"{path}: expected one config record, found {len(configs)}")
    require(rows, f"{path}: no result records")
    config = dict(configs[0])
    legacy_widths = "width_filter" not in config
    # Normalize the initial single-block harness format too. New files explicitly
    # record these selectors, allowing detection of incomplete benchmark runs.
    operations = {key[0] for key in rows}
    apis = {key[1] for key in rows}
    widths = {key[2] for key in rows}
    config.setdefault("mode", next(iter(operations)) if len(operations) == 1 else "both")
    config.setdefault("api", next(iter(apis)) if len(apis) == 1 else "both")
    config.setdefault("width_filter", next(iter(widths)) if len(widths) == 1 else 0)
    for field in ("zig", "arch", "cpu", "optimize", "seed", "blocks", "samples"):
        require(field in config, f"{path}: config missing {field}")
    if "zig_backend" in config:
        require(isinstance(config["zig_backend"], str) and config["zig_backend"].strip(), f"{path}: invalid Zig backend")
    if "cpu_features" in config:
        features = config["cpu_features"]
        require(isinstance(features, list) and features and all(isinstance(mask, str) and re.fullmatch(r"[0-9a-f]{16}", mask) for mask in features), f"{path}: invalid CPU feature bitset")
    require(type(config["seed"]) is int and 0 <= config["seed"] < 2**64, f"{path}: invalid seed")
    require(type(config["blocks"]) is int and config["blocks"] > 0, f"{path}: invalid configured block count")
    require(type(config["samples"]) is int and 3 <= config["samples"] <= 101, f"{path}: invalid sample count")
    require(config["mode"] in ("encrypt", "decrypt", "both"), f"{path}: invalid configured mode")
    require(config["api"] in ("single", "bulk", "both"), f"{path}: invalid configured API")
    require(type(config["width_filter"]) is int and config["width_filter"] in (0, *SUPPORTED_WIDTHS), f"{path}: invalid configured width")
    expected_operations = ("encrypt", "decrypt") if config["mode"] == "both" else (config["mode"],)
    expected_apis = ("single", "bulk") if config["api"] == "both" else (config["api"],)
    default_widths = (1, 2, 4, 8, 16) if legacy_widths else DEFAULT_WIDTHS
    expected_widths = default_widths if config["width_filter"] == 0 else (config["width_filter"],)
    expected = set(itertools.product(expected_operations, expected_apis, expected_widths))
    require(set(rows) == expected, f"{path}: incomplete or unexpected workloads; missing={sorted(expected - set(rows))}, extra={sorted(set(rows) - expected)}")
    reference_checksums = {}
    for (operation, api, width), row in rows.items():
        label = f"{path}: {operation}/{api}/width={width}"
        blocks = row.get("blocks")
        samples = row.get("samples")
        expected_blocks = ((config["blocks"] + width - 1) // width) * width
        require(type(blocks) is int and blocks == expected_blocks, f"{label}: block count does not match config")
        require(type(samples) is int and samples == config["samples"], f"{label}: sample count does not match config")
        elapsed = row.get("elapsed_ns")
        require(isinstance(elapsed, list) and len(elapsed) == samples, f"{label}: wrong raw sample count")
        require(all(type(value) is int and value > 0 for value in elapsed), f"{label}: elapsed samples must be positive integers")
        for field in ("median_ns_per_block", "min_ns_per_block", "median_mib_per_s"):
            require(positive_number(row.get(field)), f"{label}: invalid {field}")
        median = statistics.median(elapsed) / blocks
        minimum = min(elapsed) / blocks
        require(abs(row["median_ns_per_block"] - median) <= 0.00051, f"{label}: median does not match raw samples")
        require(abs(row["min_ns_per_block"] - minimum) <= 0.00051, f"{label}: minimum does not match raw samples")
        mib_per_second = 16 * 1_000_000_000 / (1024 * 1024) / median
        require(abs(row["median_mib_per_s"] - mib_per_second) <= 0.00051, f"{label}: throughput does not match raw samples")
        checksum = row.get("checksum")
        require(isinstance(checksum, str) and re.fullmatch(r"[0-9a-fA-F]{16}", checksum), f"{label}: invalid checksum")
        row["checksum"] = checksum.lower()
        checksum_key = operation, width
        require(reference_checksums.setdefault(checksum_key, row["checksum"]) == row["checksum"], f"{label}: single and bulk checksums differ")
    return config, rows


def compare(before_path, after_path):
    before_config, before_rows = load_run(before_path)
    after_config, after_rows = load_run(after_path)
    mismatches = [f"{key}: {before_config.get(key)!r} != {after_config.get(key)!r}"
                  for key in sorted(set(before_config) | set(after_config))
                  if before_config.get(key) != after_config.get(key)]
    require(not mismatches, "configurations differ: " + "; ".join(mismatches))
    require(set(before_rows) == set(after_rows), "workload sets differ")
    comparisons = []
    for key in sorted(before_rows):
        before, after = before_rows[key], after_rows[key]
        label = f"{key[0]}/{key[1]}/width={key[2]}"
        for field in ("blocks", "samples", "checksum"):
            require(before[field] == after[field], f"{label}: {field} differs: {before[field]!r} != {after[field]!r}")
        before_ns = statistics.median(before["elapsed_ns"]) / before["blocks"]
        after_ns = statistics.median(after["elapsed_ns"]) / after["blocks"]
        before_min = min(before["elapsed_ns"]) / before["blocks"]
        after_min = min(after["elapsed_ns"]) / after["blocks"]
        comparisons.append({
            "operation": key[0], "api": key[1], "width": key[2],
            "blocks": before["blocks"], "samples": before["samples"],
            "checksum": before["checksum"],
            "before_bulk_available": before["bulk_available"],
            "after_bulk_available": after["bulk_available"],
            "before_median_ns_per_block": before_ns,
            "after_median_ns_per_block": after_ns,
            "median_speedup": before_ns / after_ns,
            "before_min_ns_per_block": before_min,
            "after_min_ns_per_block": after_min,
            "min_speedup": before_min / after_min,
        })
    return {"before": str(before_path), "after": str(after_path), "config": before_config, "results": comparisons}


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("before", type=Path, help="baseline benchmark JSONL")
    parser.add_argument("after", type=Path, help="candidate benchmark JSONL")
    parser.add_argument("--json", action="store_true", help="emit a machine-readable comparison")
    args = parser.parse_args()
    try:
        comparison = compare(args.before, args.after)
    except (InvalidRun, OSError) as error:
        parser.exit(1, f"error: {error}\n")
    if args.json:
        json.dump(comparison, sys.stdout, indent=2, allow_nan=False)
        print()
        return
    print(f"Validated matching configuration, workloads and checksums: {args.before} -> {args.after}")
    print(f"{'Operation':<9} {'API':<6} {'Width':>5} {'Before ns':>11} {'After ns':>11} {'Speedup':>9} {'Min speedup':>12} {'Bulk before/after':>18}")
    for row in comparison["results"]:
        availability = f"{str(row['before_bulk_available']).lower()}/{str(row['after_bulk_available']).lower()}"
        print(f"{row['operation']:<9} {row['api']:<6} {row['width']:>5} "
              f"{row['before_median_ns_per_block']:>11.3f} {row['after_median_ns_per_block']:>11.3f} "
              f"{row['median_speedup']:>8.3f}x {row['min_speedup']:>11.3f}x {availability:>18}")


if __name__ == "__main__":
    main()
