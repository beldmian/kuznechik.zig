#!/usr/bin/env python3
"""Summarize paired OFB confirmations. Standard library; no source mutation."""
import json
from pathlib import Path
from statistics import median

root = Path(__file__).resolve().parent
runs = {}
for name in ("dispatch1", "dispatch2", "dispatch-reverse"):
    rows = [json.loads(line) for line in (root / (name + ".jsonl")).read_text().splitlines()]
    assert len(rows) == 64
    cases = {}
    for row in rows:
        assert row["mode"] == "OFB-xor"
        assert len(row["before"]) == len(row["after"]) == 15
        pairs = [a / b for a, b in zip(row["after"], row["before"])]
        if name.endswith("reverse"):
            pairs = [1 / x for x in pairs]
        key = (row["m"], row["bytes"], row["split1"])
        assert key not in cases
        cases[key] = {"median_ratio": median(pairs), "ratios": pairs,
                      "seed": row["seed"], "checksum": row["checksum"]}
    runs[name] = cases
assert all(set(cases) == set(runs["dispatch1"]) for cases in runs.values())
summary = [{"m": key[0], "bytes": key[1], "split1": key[2],
            "median_ratio": median(cases[key]["median_ratio"] for cases in runs.values()),
            "runs": {name: cases[key] for name, cases in runs.items()}}
           for key in sorted(runs["dispatch1"])]
(root / "dispatch-summary.json").write_text(json.dumps(summary, indent=2) + "\n")
print(json.dumps({"case_count": len(summary), "pairs_per_case": 45,
                  "max_changed_median": max(x["median_ratio"] for x in summary if x["m"] >= 64),
                  "max_control_median": max(x["median_ratio"] for x in summary if x["m"] < 64)}, indent=2))
