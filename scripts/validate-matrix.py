#!/usr/bin/env python3
"""Run named full-suite configurations, preserving output and resource receipts."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parent.parent
PROFILES = {f"{cpu}-{opt.lower()}": ["-mcpu=" + cpu, "-O" + opt, "-fllvm"]
            for cpu in ("baseline", "native")
            for opt in ("Debug", "ReleaseSafe", "ReleaseFast")}
PROFILES.update({f"{cpu}-selfhosted-debug": ["-mcpu=" + cpu, "-ODebug", "-fno-llvm"]
                 for cpu in ("baseline", "native")})
if platform.machine() == "x86_64":
    for feature in ("gfni", "avx512vbmi", "avx512vl", "avx2"):
        PROFILES["native-without-" + feature] = ["-mcpu=native-" + feature, "-OReleaseFast", "-fllvm"]


def read_inventory(log):
    """Require every numbered test and verify the final pass/skip summary."""
    tests = []
    total = None
    for line in log.splitlines():
        match = re.fullmatch(r"(\d+)/(\d+) (.+)\.\.\.(OK|SKIP)", line)
        if match:
            index, count = map(int, match.group(1, 2))
            if index != len(tests) + 1 or (total is not None and count != total):
                raise ValueError("incomplete or inconsistent numbered test inventory")
            total = count
            tests.append({"name": match[3], "status": match[4]})
    if not tests or len(tests) != total:
        raise ValueError("missing complete numbered test inventory")
    passed = sum(test["status"] == "OK" for test in tests)
    skipped = total - passed
    summary = (f"All {total} tests passed." if not skipped else
               f"{passed} passed; {skipped} skipped; 0 failed.")
    if log.splitlines()[-1:] != [summary]:
        raise ValueError("missing or inconsistent final test summary")
    return {"total": total, "passed": passed, "skipped": skipped, "tests": tests}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--zig", default="zig")
    parser.add_argument("--output", required=True, help="new output directory (never overwritten)")
    parser.add_argument("profiles", nargs="*", choices=sorted(PROFILES))
    args = parser.parse_args()
    out = Path(args.output).absolute()
    out.mkdir(parents=True, exist_ok=False)
    zig = str(Path(args.zig).resolve()) if os.path.sep in args.zig else args.zig
    metadata = {"zig_version": subprocess.check_output([zig, "version"], text=True).strip(),
                "platform": platform.platform(), "machine": platform.machine(),
                "cpuinfo": Path('/proc/cpuinfo').read_text() if Path('/proc/cpuinfo').exists() else None}
    (out / 'host.json').write_text(json.dumps(metadata, indent=2) + '\n')
    sources = {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest()
               for path in sorted((ROOT / 'src').rglob('*')) if path.is_file()}
    (out / 'sources.json').write_text(json.dumps(sources, indent=2) + '\n')
    failures = []
    for name in args.profiles or PROFILES:
        with tempfile.TemporaryDirectory(prefix="kuz-validate-") as cache:
            env = os.environ.copy()
            env['ZIG_LOCAL_CACHE_DIR'] = cache + '/local'
            env['ZIG_GLOBAL_CACHE_DIR'] = cache + '/global'
            command = [zig, 'test', str(ROOT / 'src/kuznechik.zig'), *PROFILES[name]]
            (out / (name + '.command.json')).write_text(json.dumps({
                'argv': command, 'local_cache': env['ZIG_LOCAL_CACHE_DIR'],
                'global_cache': env['ZIG_GLOBAL_CACHE_DIR'],
            }, indent=2) + '\n')
            # A fresh helper process makes ru_maxrss specific to this build and test.
            helper = '''import json,resource,subprocess,sys,time\ns=time.monotonic()\np=subprocess.run(sys.argv[2:])\nopen(sys.argv[1],"w").write(json.dumps({"elapsed_seconds":time.monotonic()-s,"peak_child_rss_kib":resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss,"exit_code":p.returncode},indent=2)+"\\n")\nsys.exit(p.returncode)'''
            print(name, flush=True)
            with (out / (name + '.log')).open('w') as log:
                result = subprocess.run([sys.executable, '-c', helper, str(out / (name + '.json')), *command], cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT)
            if result.returncode:
                failures.append(name)
                continue
            try:
                inventory = read_inventory((out / (name + '.log')).read_text())
            except ValueError as error:
                print(f"{name}: {error}", flush=True)
                failures.append(name)
            else:
                (out / (name + '.inventory.json')).write_text(json.dumps(inventory, indent=2) + '\n')
    print('Failed profiles:', ', '.join(failures) if failures else 'none')
    return bool(failures)


if __name__ == '__main__':
    sys.exit(main())
