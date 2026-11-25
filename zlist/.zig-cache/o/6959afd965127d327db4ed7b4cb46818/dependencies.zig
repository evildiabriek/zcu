pub const packages = struct {
    pub const @"zlib-0.0.0-oos5cB2GAABb6be0_Rd9PRZmKiybJGBSuSrwQfJH0jdf" = struct {
        pub const build_root = "zig-pkg/zlib-0.0.0-oos5cB2GAABb6be0_Rd9PRZmKiybJGBSuSrwQfJH0jdf";
        pub const build_zig = @import("zlib-0.0.0-oos5cB2GAABb6be0_Rd9PRZmKiybJGBSuSrwQfJH0jdf");
        pub const deps: []const struct { []const u8, []const u8 } = &.{
        };
    };
};

pub const root_deps: []const struct { []const u8, []const u8 } = &.{
    .{ "zlib", "zlib-0.0.0-oos5cB2GAABb6be0_Rd9PRZmKiybJGBSuSrwQfJH0jdf" },
};
