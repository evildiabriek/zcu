pub const packages = struct {
    pub const @"zlib-0.0.0-oos5cCKGAAC7dccxBLLlaTZRF4Ek2DMurZ3VOaUg89Bw" = struct {
        pub const build_root = "zig-pkg/zlib-0.0.0-oos5cCKGAAC7dccxBLLlaTZRF4Ek2DMurZ3VOaUg89Bw";
        pub const build_zig = @import("zlib-0.0.0-oos5cCKGAAC7dccxBLLlaTZRF4Ek2DMurZ3VOaUg89Bw");
        pub const deps: []const struct { []const u8, []const u8 } = &.{
        };
    };
};

pub const root_deps: []const struct { []const u8, []const u8 } = &.{
    .{ "zlib", "zlib-0.0.0-oos5cCKGAAC7dccxBLLlaTZRF4Ek2DMurZ3VOaUg89Bw" },
};
