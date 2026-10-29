//! Standalone OCB test entrypoint before root integration.
//! zig test src/ocb_test.zig -O ReleaseSafe
// Keep the module root at src so mode tests can also exercise Kuznechik.
test {
    _ = @import("modes/ocb.zig");
}
