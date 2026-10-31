import json,os,resource,signal,subprocess,time
from pathlib import Path
out=Path('/home/user/selfhosted-probe');out.mkdir(exist_ok=False)
command=['/tmp/zig-x86_64-linux-0.15.2/zig','test','src/kuznechik.zig','-target','aarch64-linux-musl','-mcpu=baseline','-ODebug','-fno-llvm','--test-no-exec','-femit-bin='+str(out/'test')]
(out/'command.json').write_text(json.dumps(command,indent=2)+'\n')
start=time.monotonic();reason=None
with (out/'compile.log').open('w') as log, (out/'samples.jsonl').open('w') as samples:
 p=subprocess.Popen(command,cwd='/home/user/kuz-work',stdout=log,stderr=subprocess.STDOUT,start_new_session=True)
 last=-15
 while p.poll() is None:
  elapsed=time.monotonic()-start
  try:
   fields=Path(f'/proc/{p.pid}/stat').read_text().split();rss=int(fields[23])*os.sysconf('SC_PAGE_SIZE')//1024;cpu=(int(fields[13])+int(fields[14]))/os.sysconf('SC_CLK_TCK')
  except (FileNotFoundError,ProcessLookupError):break
  sample={'elapsed_seconds':round(elapsed,2),'rss_kib':rss,'cpu_seconds':cpu,'output_bytes':(out/'test').stat().st_size if (out/'test').exists() else 0}
  samples.write(json.dumps(sample)+'\n');samples.flush()
  if elapsed-last>=15:print(json.dumps(sample),flush=True);last=elapsed
  if elapsed>240 or rss>5*1024*1024:
   reason='240-second time limit' if elapsed>240 else '5-GiB RSS diagnostic limit';os.killpg(p.pid,signal.SIGTERM)
   try:p.wait(timeout=10)
   except subprocess.TimeoutExpired:os.killpg(p.pid,signal.SIGKILL)
   break
  time.sleep(1)
 rc=p.wait()
receipt={'exit_code':rc,'stop_reason':reason,'elapsed_seconds':time.monotonic()-start,'peak_child_rss_kib':resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss}
(out/'result.json').write_text(json.dumps(receipt,indent=2)+'\n');print(json.dumps(receipt),flush=True)
print((out/'compile.log').read_text()[-6000:],flush=True)
