#!/usr/bin/env python3
"""Read back every VM archive member and verify its SHA, then extract."""
import hashlib,json,pathlib,sys,tarfile
archive=pathlib.Path(sys.argv[1]);dest=pathlib.Path(sys.argv[2]);dest.mkdir(parents=True,exist_ok=True)
with tarfile.open(archive,'r:gz') as tf:
 manifest=json.load(tf.extractfile('vm-artifacts.sha256.json'))
 members={m.name:m for m in tf.getmembers() if m.isfile()}
 assert set(members)==set(manifest)|{'vm-artifacts.sha256.json'}
 for name,digest in manifest.items():assert hashlib.sha256(tf.extractfile(members[name]).read()).hexdigest()==digest,name
 tf.extractall(dest,filter='data')
result=dict(archive_sha256=hashlib.sha256(archive.read_bytes()).hexdigest(),verified_files=len(manifest),all_members_read_back=True,passed=True)
(dest/'transfer-verification.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
