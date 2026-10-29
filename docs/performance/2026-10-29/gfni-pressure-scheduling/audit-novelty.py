#!/usr/bin/env python3
"""Compare canonical node orders with the prior eight DFS/six uniform families."""
import itertools,json,pathlib,sys
s=pathlib.Path(sys.argv[1]);p=json.loads((s/'proof.json').read_text());nn=p['nodes'];oo=p['outputs'];cache={tuple(n):i for i,n in enumerate(nn)}
def deps(i):return nn[i][1:] if nn[i][0]=='xor' else nn[i][1:2] if nn[i][0]=='mul' else []
def arithmetic(order):return [i for i in order if nn[i][0] not in ['zero','input']]
prior={}
for outputs,label in [(oo,'forward'),(oo[::-1],'reverse'),([oo[j] for i in range(8) for j in (i,i+8)],'paired'),([oo[j] for i in range(7,-1,-1) for j in (i+8,i)],'paired-reverse')]:
 for reverse in (False,True):
  order=[];seen=set()
  def walk(i):
   if i in seen:return
   seen.add(i)
   for j in deps(i)[::-1] if reverse else deps(i):walk(j)
   order.append(i)
  for o in outputs:walk(o)
  prior['dfs-'+label+('-r' if reverse else '')]=arithmetic(order)
for perm in itertools.permutations(range(3)):
 created=[];seen=set(range(17))
 def node(n):
  i=cache[tuple(n)]
  if i not in seen:seen.add(i);created.append(i)
  return i
 def xor(a,b):return 0 if a==b else b if not a else a if not b else node(('xor',min(a,b),max(a,b)))
 def prod(a,c):return 0 if not a or not c else a if c==1 else node(('mul',a,c))
 def transform(t,x):
  n=len(t)
  if n==1:return [prod(x[0],t[0][0])]
  m=n//2;a=[r[:m] for r in t[:m]]
  mats=[a,[[a[i][j]^t[i][m+j] for j in range(m)] for i in range(m)],[[a[i][j]^t[m+i][j] for j in range(m)] for i in range(m)]]
  results={}
  for k in perm:results[k]=transform(mats[k],[xor(x[i],x[m+i]) for i in range(m)] if k==0 else x[m:] if k==1 else x[:m])
  return [xor(results[0][i],results[1][i]) for i in range(m)]+[xor(results[0][i],results[2][i]) for i in range(m)]
 outputs=transform(p['matrix'],list(range(1,17)));assert outputs==oo
 # Prior variants emitter discarded dead nodes and deferred all final outputs.
 active=set(prior['dfs-forward'])
 prior['recursive-'+''.join('pqr'[i] for i in perm)]=[i for i in created if i in active and i not in oo]+oo
new=json.loads((s/'schedules.json').read_text());matches={name:[label for label,order in prior.items() if v['order']==order] for name,v in new.items()}
(s/'novelty-audit.json').write_text(json.dumps(dict(prior_orders=prior,schedule_matches=matches,new_orders=sum(not v for v in matches.values())),indent=2)+'\n')
print('New orders',sum(not v for v in matches.values()),'of',len(matches),'matches',{k:v for k,v in matches.items() if v})
