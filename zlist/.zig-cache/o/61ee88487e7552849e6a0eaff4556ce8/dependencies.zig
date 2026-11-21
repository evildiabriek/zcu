pub const packages = struct {
    pub const @"zlib-0.0.0-oos5cP-EAABQkZt73TVztyPe4qPIO_amU1hm_kyURjs2" = struct {
        pub const build_root = "zig-pkg/zlib-0.0.0-oos5cP-EAABQkZt73TVztyPe4qPIO_amU1hm_kyURjs2";
        pub const build_zig = @import("zlib-0.0.0-oos5cP-EAABQkZt73TVztyPe4qPIO_amU1hm_kyURjs2");
        pub const deps: []const struct { []const u8, []const u8 } = &.{
        };
    };
};

pub const root_deps: []const struct { []const u8, []const u8 } = &.{
    .{ "zlib", "zlib-0.0.0-oos5cP-EAABQkZt73TVztyPe4qPIO_amU1hm_kyURjs2" },
};
