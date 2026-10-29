#!/usr/bin/env python3
"""Generate tables and an interactive chart from validated benchmark JSONL."""

import argparse
import csv
import importlib.util
import json
from pathlib import Path
import statistics
import sys

sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location("perf_compare", Path(__file__).with_name("perf-compare.py"))
compare_module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(compare_module)

HTML = """<!doctype html>
<html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Kuznechik measured performance</title>
<style>
:root{color-scheme:light dark;font-family:var(--font-sans,system-ui);color:var(--foreground)}
html,body{margin:0;padding:0;background:transparent}
.controls{display:flex;flex-wrap:wrap;gap:12px;margin-bottom:12px}
label{display:flex;flex-direction:column;gap:5px;font-size:13px}
select{font:inherit;padding:7px;border:1px solid var(--border,currentColor);border-radius:var(--radius,6px);background:var(--card);color:var(--foreground);max-width:100%}
.legend{display:flex;gap:18px;font-size:13px;margin-bottom:6px}
.key{display:inline-block;width:12px;height:9px;margin-right:5px}
.before{background:var(--muted-foreground,gray)}
.after{background:var(--chart-2,seagreen)}
svg{width:100%;height:440px;display:block;overflow:visible}
svg text{font-family:var(--font-sans,system-ui);font-size:14px;fill:var(--foreground,currentColor)}
svg .axis{font-size:12px;fill:var(--muted-foreground,currentColor)}
.caption{font-size:12px;line-height:1.5;color:var(--muted-foreground,currentColor);margin:8px 0 0}
@media(max-width:480px){svg text{font-size:20px}svg .axis{font-size:17px}.controls{display:block}label{margin-bottom:10px}svg{height:450px}}
</style>
<div class="controls">
<label>Machine<select id="machine" aria-label="Machine"></select></label>
<label>Independent batch size<select id="batch" aria-label="Independent batch size"></select></label>
</div>
<div class="legend"><span><i class="key before"></i>Original</span><span><i class="key after"></i>Optimized</span></div>
<svg viewBox="0 0 600 430" role="img" aria-label="Original versus optimized nanoseconds per block"></svg>
<p class="caption" id="profile"></p>
<p class="caption">Lower nanoseconds per block is better. Bars show medians; whiskers show the sample interquartile range. Compare ratios within each machine. Single-block chains and independent batch throughput are separate workloads.</p>
<script>
const profiles=__DATA__;
const machine=document.getElementById('machine'),batch=document.getElementById('batch'),svg=document.querySelector('svg');
profiles.forEach(function(p,i){const o=document.createElement('option');o.value=i;o.textContent=p.label;machine.append(o)});
function node(tag,attrs,text){const e=document.createElementNS('http://www.w3.org/2000/svg',tag);Object.keys(attrs).forEach(function(k){e.setAttribute(k,attrs[k])});if(text!==undefined)e.textContent=text;svg.append(e);return e}
function choices(){const p=profiles[Number(machine.value)],old=batch.value;batch.replaceChildren();p.widths.forEach(function(w){const o=document.createElement('option');o.value=w;o.textContent=w+' blocks';batch.append(o)});batch.value=p.widths.includes(Number(old))?old:'256';draw()}
function draw(){
 const p=profiles[Number(machine.value)],width=Number(batch.value);svg.replaceChildren();
 const rows=[['encrypt','single',1],['decrypt','single',1],['encrypt','bulk',width],['decrypt','bulk',width]].map(function(k){return p.rows.find(function(r){return r.operation===k[0]&&r.api===k[1]&&r.width===k[2]})});
 const top=Math.ceil(Math.max.apply(null,rows.map(function(r){return Math.max(r.before[2],r.after[2])}))/10)*10,scale=420/top;
 for(let i=0;i<=4;i++){const x=top*i/4*scale;node('line',{x1:x,y1:8,x2:x,y2:388,stroke:'var(--border,currentColor)',opacity:0.25});node('text',{x:x,y:411,class:'axis','text-anchor':i===0?'start':'middle'},(top*i/4).toFixed(0))}
 rows.forEach(function(r,i){
  const y=20+i*92,title=(r.api==='single'?'Single-block chain':'Independent batch')+' · '+r.operation;
  node('text',{x:0,y:y},title);
  [['before','var(--muted-foreground,gray)'],['after','var(--chart-2,seagreen)']].forEach(function(kind,j){
   const a=r[kind[0]],barY=y+12+j*24,mid=barY+6;
   const rect=node('rect',{x:0,y:barY,width:Math.max(1,a[0]*scale),height:12,rx:2,fill:kind[1]});
   const tip=document.createElementNS('http://www.w3.org/2000/svg','title');tip.textContent=kind[0]+': '+a[0].toFixed(3)+' ns/block';rect.append(tip);
   node('line',{x1:a[1]*scale,y1:mid,x2:a[2]*scale,y2:mid,stroke:'var(--foreground,currentColor)','stroke-width':1.5});
   [a[1],a[2]].forEach(function(v){node('line',{x1:v*scale,y1:mid-4,x2:v*scale,y2:mid+4,stroke:'var(--foreground,currentColor)'})});
   node('text',{x:a[0]*scale+9,y:barY+11},a[0].toFixed(2)+' ns'+(j===1?' · '+r.speedup.toFixed(2)+'×':''));
  });
 });
 document.getElementById('profile').textContent=p.config.zig+' · '+p.config.cpu+' · '+p.config.optimize+' · '+(p.config.zig_backend||'backend not recorded')+' · '+p.config.samples+' samples × '+p.config.blocks.toLocaleString()+' requested blocks. Timing excludes key setup.';
}
machine.addEventListener('change',choices);batch.addEventListener('change',draw);choices();
</script></html>
"""


def sample_stats(row):
    values = [value / row["blocks"] for value in row["elapsed_ns"]]
    quartiles = statistics.quantiles(values, n=4, method="inclusive")
    return [statistics.median(values), quartiles[0], quartiles[2]]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("data", type=Path, help="directory containing paired JSONL runs")
    parser.add_argument("--output", type=Path, help="report directory (default: parent of data)")
    args = parser.parse_args()
    output = args.output or args.data.parent
    profiles = []
    for prefix, role in (
        ("boat-c", "Boat C"),
        ("boat-d", "Boat D"),
        ("boat-e", "Boat E"),
        ("broadwell", "local"),
    ):
        before = args.data / f"{prefix}-baseline.jsonl"
        after = args.data / f"{prefix}-candidate.jsonl"
        if not before.exists() and not after.exists():
            continue
        comparison = compare_module.compare(before, after)
        if comparison["config"].get("width_filter") != 0 or comparison["config"].get("api") != "both" or comparison["config"].get("mode") != "both":
            raise ValueError(f"{prefix}: summary requires the full default grid with --api both")
        model = comparison["config"]["cpu"]
        machine_file = args.data / f"{prefix}-machine.json"
        if machine_file.exists():
            machine = json.loads(machine_file.read_text())
            model = next((item["data"] for item in machine.get("lscpu", []) if item["field"] == "Model name:"), model)
        for token, short in (("9950X", "Ryzen 9 9950X"), ("9700X", "Ryzen 7 9700X"), ("E5-2690", "Xeon E5-2690 v4")):
            if token in model:
                model = short
                break
        label = f"{model} · {role}"
        _, old = compare_module.load_run(before)
        _, new = compare_module.load_run(after)
        pairs = [(comparison, old, new)]
        tail_before = args.data / f"{prefix}-tail-baseline.jsonl"
        tail_after = args.data / f"{prefix}-tail-candidate.jsonl"
        if tail_before.exists() or tail_after.exists():
            tail_comparison = compare_module.compare(tail_before, tail_after)
            for key, value in comparison["config"].items():
                if key != "width_filter" and tail_comparison["config"].get(key) != value:
                    raise ValueError(f"{prefix}: main and tail configurations differ at {key}")
            pairs.append((tail_comparison, compare_module.load_run(tail_before)[1], compare_module.load_run(tail_after)[1]))
        rows = []
        for comp, old, new in pairs:
            for row in comp["results"]:
                if row["api"] == "single" and row["width"] != 1:
                    continue
                key = row["operation"], row["api"], row["width"]
                rows.append({
                    "operation": key[0], "api": key[1], "width": key[2],
                    "before": sample_stats(old[key]), "after": sample_stats(new[key]),
                    "speedup": row["median_speedup"],
                })
        profiles.append({
            "id": prefix, "label": label, "config": comparison["config"], "rows": rows,
            "widths": sorted({row["width"] for row in rows if row["api"] == "bulk" and row["width"] > 1}),
        })
    if not profiles:
        parser.error("no paired benchmark files found")
    output.mkdir(parents=True, exist_ok=True)
    (args.data / "summary.json").write_text(json.dumps({"profiles": profiles}, indent=2, allow_nan=False) + "\n")
    with (args.data / "summary.csv").open("w", newline="") as file:
        writer = csv.writer(file)
        writer.writerow(["profile", "operation", "api", "width", "before_ns", "after_ns", "speedup"])
        for profile in profiles:
            for row in profile["rows"]:
                writer.writerow([profile["id"], row["operation"], row["api"], row["width"], row["before"][0], row["after"][0], row["speedup"]])
    lines = [
        "# Recorded performance comparisons", "",
        "Generated by scripts/perf-report.py from validated matching configurations and checksums.",
        "Times are median nanoseconds per block; lower is better. All ratios are within one machine.", "",
        "| Machine | Operation | Single before → after | Speedup | Batch 256 before → after | Speedup |",
        "|---|---|---:|---:|---:|---:|",
    ]
    for profile in profiles:
        for operation in ("encrypt", "decrypt"):
            single = next(r for r in profile["rows"] if r["operation"] == operation and r["api"] == "single" and r["width"] == 1)
            bulk = next(r for r in profile["rows"] if r["operation"] == operation and r["api"] == "bulk" and r["width"] == 256)
            lines.append(f"| {profile['label']} | {operation} | {single['before'][0]:.2f} → {single['after'][0]:.2f} | {single['speedup']:.2f}× | {bulk['before'][0]:.2f} → {bulk['after'][0]:.2f} | {bulk['speedup']:.2f}× |")
    lines += ["", "Batch results use independent raw blocks. They are not single-block latency or serial-mode speedups.",
              "Broadwell single-block decryption retains the original schedule; its small observed difference is not evidence of a new decryption kernel.", "",
              f"Raw files and machine metadata: [{args.data.name}]({args.data.name}/).",
              "An [interactive chart](results.html) includes other measured batch sizes and sample interquartile ranges.", ""]
    (output / "RESULTS.md").write_text("\n".join(lines))
    embedded = json.dumps(profiles, separators=(",", ":"), allow_nan=False).replace("<", "\\u003c")
    (output / "results.html").write_text(HTML.replace("__DATA__", embedded))
    print(f"Validated {len(profiles)} profiles; wrote RESULTS.md, results.html, summary.json, summary.csv")


if __name__ == "__main__":
    main()
