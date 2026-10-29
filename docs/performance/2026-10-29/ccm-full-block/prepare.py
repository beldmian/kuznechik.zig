#!/usr/bin/env python3
import io,pathlib,subprocess,sys,tarfile
repo=pathlib.Path(sys.argv[1]).resolve(); stage=pathlib.Path(sys.argv[2]).resolve()
archive=subprocess.check_output(['git','-C',str(repo),'archive','b2c467c','src'])
with tarfile.open(fileobj=io.BytesIO(archive)) as tf:
 for m in tf.getmembers():
  if not m.isfile():continue
  p=stage/'baseline'/pathlib.PurePosixPath(m.name).relative_to('src')
  p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(tf.extractfile(m).read())
s=(stage/'baseline/modes/ccm.zig').read_text()
s=s.replace('''            fn flush(self: *@This()) void {
                self.state ^= @as(B, self.buffer);
                self.cipher.encrypt(&self.state);
                self.used = 0;
            }''','''            fn fullBlock(self: *@This(), input: B) void {
                self.state ^= input;
                self.cipher.encrypt(&self.state);
            }
            fn flush(self: *@This()) void {
                self.fullBlock(self.buffer);
                self.used = 0;
            }''')
a=s.index('            fn update(self: *@This(), input: []const u8) void {')
b=s.index('            fn pad(self:',a)
s=s[:a]+'''            fn update(self: *@This(), input: []const u8) void {
                var data = input;
                if (self.used != 0) {
                    const n = @min(16 - self.used, data.len);
                    @memcpy(self.buffer[self.used..][0..n], data[0..n]);
                    self.used += n;
                    data = data[n..];
                    if (self.used < 16) return;
                    self.flush();
                }
                // Payload and long AAD runs need no intermediate buffer.
                // Load through a byte array so unaligned input remains valid.
                while (data.len >= 16) {
                    self.fullBlock(data[0..16].*);
                    data = data[16..];
                }
                @memcpy(self.buffer[0..data.len], data);
                self.used = data.len;
            }
'''+s[b:]
old='''                    var plain: [16]u8 = @splat(0);
                    @memcpy(plain[0..n], data[at + i * 16 ..][0..n]);
                    plain = @as(B, plain) ^ gamma[i];
                    mac.update(plain[0..n]);'''
new='''                    if (n == 16) {
                        // Payload MAC input starts at a block boundary. Keep
                        // decrypted full blocks private until authentication.
                        const encrypted: [16]u8 = data[at + i * 16 ..][0..16].*;
                        mac.fullBlock(@as(B, encrypted) ^ gamma[i]);
                    } else {
                        var plain: [16]u8 = @splat(0);
                        @memcpy(plain[0..n], data[at + i * 16 ..][0..n]);
                        plain = @as(B, plain) ^ gamma[i];
                        mac.update(plain[0..n]);
                    }'''
assert old in s;s=s.replace(old,new)
p=stage/'candidate/ccm.zig';p.parent.mkdir(parents=True,exist_ok=True);p.write_text(s)
# Full source tree for correctness testing of the candidate mode.
import shutil
full=stage/'candidate-tree'
if full.exists():shutil.rmtree(full)
shutil.copytree(stage/'baseline',full)
(full/'modes/ccm.zig').write_text(s)
