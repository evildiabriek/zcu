pub const packages = struct {
    pub const @"zlib-0.0.0-oos5cD-FAABAQRlpukk_lqCoXhXwI4PRJifZjQB-Gg7T" = struct {
        pub const build_root = "zig-pkg/zlib-0.0.0-oos5cD-FAABAQRlpukk_lqCoXhXwI4PRJifZjQB-Gg7T";
        pub const build_zig = @import("zlib-0.0.0-oos5cD-FAABAQRlpukk_lqCoXhXwI4PRJifZjQB-Gg7T");
        pub const deps: []const struct { []const u8, []const u8 } = &.{
        };
    };
};

pub const root_deps: []const struct { []const u8, []const u8 } = &.{
    .{ "zlib", "zlib-0.0.0-oos5cD-FAABAQRlpukk_lqCoXhXwI4PRJifZjQB-Gg7T" },
};
