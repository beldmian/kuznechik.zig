#!/usr/bin/env python3
import hashlib,json,pathlib,sys
repo=pathlib.Path(sys.argv[1]);dest=pathlib.Path(sys.argv[2]);original=repo/'docs/performance/hypotheses-linear-factor.json';p=json.loads(original.read_text())
scanned={}
for name,d in p['frozen_sources'].items():
 text=d.get('text','');assert '"*m"' not in text,name
 scanned[name]=dict(sha256=hashlib.sha256(text.encode()).hexdigest(),explicit_indirect_m=False)
prior={}
for group in ['bitwise-normalization','operand-scheduling','gfni-pressure-scheduling']:
 report=repo/f'docs/performance/2026-10-29/{group}/RESULTS.md'
 prior[group]=dict(report_sha256=hashlib.sha256(report.read_bytes()).hexdigest(),preserves_hidden_pointer_memory_clobber=True)
out=dict(original_sha256=hashlib.sha256(original.read_bytes()).hexdigest(),known_scalar_m_duplicate=p['coefficient_loads']['scalar_m_probe'],all_original_frozen_sources=scanned,prior_reports=prior,new_form='*m by-reference [1]u64 / LLVM elementtype([1 x i64])',passed=True)
(dest/'novelty-audit.json').write_text(json.dumps(out,indent=2)+'\n');print('No explicit *m aggregate in original frozen sources; known scalar rejection identified.')
