#!/usr/bin/env python3
"""Consistent before/after-release graph metrics plus explicit context assumptions.
This is a descriptive source model, not a physical-register lower bound.
"""
import collections,json,pathlib,sys
s=pathlib.Path(sys.argv[1]);p=json.loads((s/'proof.json').read_text());nn=p['nodes'];oo=p['outputs']
def deps(i):return nn[i][1:] if nn[i][0]=='xor' else nn[i][1:2] if nn[i][0]=='mul' else []
orders={k:v['order'] for k,v in json.loads((s/'schedules.json').read_text()).items()};active=set(next(iter(orders.values())))
orders['baseline']=[i for i in sorted(active) if i not in oo]+oo
out={}
for name,order in orders.items():
 uses=collections.Counter(j for i in order for j in deps(i));live={i for i in uses if nn[i][0]=='input'};before=after=len(live)
 for i in order:
  live.add(i);before=max(before,len(live))
  for j in deps(i):
   uses[j]-=1
   if not uses[j]:live.discard(j)
  after=max(after,len(live))
 assert live==set(oo)
 out[name]=dict(initial_input_vectors=16,retained_output_vectors=16,peak_before_last_use_release=before,peak_after_last_use_release=after,
  cipher_context=dict(key_vectors='current seed is 128 bits; ten round keys are public-call context, either loaded on demand or partly retained; illustrative resident-key scenarios add 1 or 10 vectors, not zero',key_context_after_release_scenarios=[after+1,after+10],gfni_constants='70 coefficient matrices are memory broadcast operands; matrix_pool base pointer consumes a GPR; hidden reads retain .memory=true',sbox_constants='position-specific 4x64-byte tables and endpoint constants can be hoisted or loaded on demand; their live vector-register count is left compiler-dependent, not treated as absent',other_context='round counters, transpose operands, and address registers are outside this value-DAG model; full cipher assembly and APIs decide'))
(s/'pressure-audit.json').write_text(json.dumps(out,indent=2)+'\n');print('baseline',out['baseline']['peak_before_last_use_release'],out['baseline']['peak_after_last_use_release'])
