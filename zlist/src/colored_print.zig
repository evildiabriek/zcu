const std = @import("std");

pub const BLACK: usize = 0;
pub const RED: usize = 1;
pub const BLUE: usize = 2;
pub const ORANGE: usize = 3;
pub const YELLOW: usize = 4;
pub const GREEN: usize = 5;
pub const GREY: usize = 6;
pub const RESET: usize = 7;

const colors = [_][]const u8{
    "\x1b[30m",
    "\x1b[31m",
    "\x1b[34m",
    "\x1b[38;5;208m",
    "\x1b[93m",
    "\x1b[32m",
    "\x1b[90m",
    "\x1b[0m",
};

pub fn cprintn(comptime fmt: []const u8, clr: usize, gpa: std.mem.Allocator, args: anytype) !void {
    const fmtt = try gpa.print(fmt, args);
    defer gpa.free(fmtt);
    std.debug.print("{s}{s}{s}\n", .{ colors[clr], fmtt, colors[6] });
}

pub fn cprint(comptime fmt: []const u8, clr: usize, gpa: std.mem.Allocator, args: anytype) !void {
    const fmtt = try gpa.print(fmt, args);
    defer gpa.free(fmtt);
    std.debug.print("{s}{s}{s}", .{ colors[clr], fmtt, colors[6] });
}
