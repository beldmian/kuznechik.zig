#!/usr/bin/env python3
"""Run named full-suite configurations, preserving output and resource receipts."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import resource
import signal
import subprocess
import sys
import tempfile
import time

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


def known_unsupported(machine, version, exit_code, diagnostic):
    # Exact compiler/backend limitation, not a generic failure-to-skip rule.
    return (machine == 'aarch64' and version == '0.15.2' and exit_code == 1
            and 'CallAbiIterator.param(@Vector(16, u8))' in diagnostic
            and 'CallAbiIterator.param(@Vector(32, u8))' in diagnostic)


def measure(receipt_path, timeout, command):
    start = time.monotonic()
    process = subprocess.Popen(command, start_new_session=True)
    timed_out = False
    try:
        code = process.wait(timeout=timeout)
    except subprocess.TimeoutExpired:
        timed_out = True
        try:
            os.killpg(process.pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
        try:
            process.wait(timeout=10)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGKILL)
            process.wait()
        code = 124
    receipt = {'elapsed_seconds': time.monotonic() - start,
               'peak_child_rss_kib': resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss,
               'exit_code': code, 'timed_out': timed_out}
    Path(receipt_path).write_text(json.dumps(receipt, indent=2) + '\n')
    return int(code != 0)


def run_measured(command, out, name, env, timeout):
    # A fresh helper process makes ru_maxrss specific to this build and test.
    (out / (name + '.command.json')).write_text(json.dumps({
        'argv': command, 'local_cache': env['ZIG_LOCAL_CACHE_DIR'],
        'global_cache': env['ZIG_GLOBAL_CACHE_DIR'], 'timeout_seconds': timeout,
    }, indent=2) + '\n')
    receipt = out / (name + '.json')
    with (out / (name + '.log')).open('w') as log:
        result = subprocess.run([sys.executable, str(Path(__file__).resolve()), '--measure',
                                 str(receipt), str(timeout), *command],
                                cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT)
    if not receipt.exists():
        raise RuntimeError(f'measurement helper exited {result.returncode} without a receipt')
    return json.loads(receipt.read_text())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--zig', default='zig')
    parser.add_argument('--output', required=True, help='new output directory (never overwritten)')
    parser.add_argument('--timeout-seconds', type=int, default=900,
                        help='per-profile build/test deadline; default 900 seconds')
    parser.add_argument('--allow-known-unsupported', action='store_true',
                        help='report the verified Zig 0.15.2 ARM vector-ABI limitation separately')
    parser.add_argument('profiles', nargs='*', choices=sorted(PROFILES))
    args = parser.parse_args()
    if args.timeout_seconds <= 0:
        parser.error('--timeout-seconds must be positive')
    out = Path(args.output).absolute()
    out.mkdir(parents=True, exist_ok=False)
    zig = str(Path(args.zig).resolve()) if os.path.sep in args.zig else args.zig
    metadata = {'zig_version': subprocess.check_output([zig, 'version'], text=True).strip(),
                'platform': platform.platform(), 'machine': platform.machine(),
                'cpuinfo': Path('/proc/cpuinfo').read_text() if Path('/proc/cpuinfo').exists() else None}
    (out / 'host.json').write_text(json.dumps(metadata, indent=2) + '\n')
    sources = {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest()
               for path in sorted((ROOT / 'src').rglob('*')) if path.is_file()}
    probe = ROOT / 'test/backend_support.zig'
    sources[str(probe.relative_to(ROOT))] = hashlib.sha256(probe.read_bytes()).hexdigest()
    (out / 'sources.json').write_text(json.dumps(sources, indent=2) + '\n')
    failures, passed, unsupported = [], [], []
    for name in args.profiles or PROFILES:
        print(name, flush=True)
        with tempfile.TemporaryDirectory(prefix='kuz-validate-') as cache:
            env = os.environ.copy()
            env['ZIG_LOCAL_CACHE_DIR'] = cache + '/local'
            env['ZIG_GLOBAL_CACHE_DIR'] = cache + '/global'
            if '-fno-llvm' in PROFILES[name]:
                probe_command = [zig, 'build-obj', str(probe), *PROFILES[name],
                                 '-femit-bin=' + cache + '/probe.o']
                result = run_measured(probe_command, out, name + '.probe', env, 30)
                if result['exit_code']:
                    diagnostic = (out / (name + '.probe.log')).read_text()
                    state = 'unsupported' if known_unsupported(metadata['machine'], metadata['zig_version'],
                                                               result['exit_code'], diagnostic) else 'failed'
                    (out / (name + '.status.json')).write_text(json.dumps({
                        'status': state, 'full_suite_executed': False,
                        'reason': diagnostic, 'probe_exit_code': result['exit_code'],
                    }, indent=2) + '\n')
                    print(f'{name}: {state} backend capability probe\n{diagnostic}', flush=True)
                    (unsupported if state == 'unsupported' else failures).append(name)
                    continue
            command = [zig, 'test', str(ROOT / 'src/kuznechik.zig'), *PROFILES[name]]
            result = run_measured(command, out, name, env, args.timeout_seconds)
            if result['exit_code']:
                print(f"{name}: build/test failed (exit {result['exit_code']}); complete diagnostic log:", flush=True)
                print((out / (name + '.log')).read_text(), flush=True)
                failures.append(name)
                continue
            try:
                inventory = read_inventory((out / (name + '.log')).read_text())
            except ValueError as error:
                print(f'{name}: {error}', flush=True)
                failures.append(name)
            else:
                (out / (name + '.inventory.json')).write_text(json.dumps(inventory, indent=2) + '\n')
                passed.append(name)
    summary = {'passed_profiles': passed, 'failed_profiles': failures, 'unsupported_profiles': unsupported,
               'allow_known_unsupported': args.allow_known_unsupported}
    (out / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
    print(json.dumps(summary), flush=True)
    return bool(failures or (unsupported and not args.allow_known_unsupported))


if __name__ == '__main__':
    if sys.argv[1:2] == ['--measure']:
        sys.exit(measure(sys.argv[2], float(sys.argv[3]), sys.argv[4:]))
    sys.exit(main())
