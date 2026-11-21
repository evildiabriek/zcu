const std = @import("std");
const zlib = @import("zlib");

// Go faire le tout premier Zcore utils (zcu): zlist (donc ls quoi)

const flagEnum = enum { DisplayName, DisplayPermission, DisplaySize, DisplayOwner, DisplayDate, DisplayPath };

const neededArg = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
};

const permission = struct {
    read: u8,
    write: u8,
    execute: u8,
};

const permissionFile = struct {
    type: u8,
    owner: permission,
    group: permission,
    others: permission,
};

const dateFormat = struct {
    day: u5,
    month: []const u8,
    year: u32,
    hour: u5,
    minute: u6,
};

const fileDescriptor = struct {
    name: []const u8,
    permission: permissionFile,
    size: usize,
    owner: []const u8,
    date: dateFormat,
    path: []const u8,
};

pub fn iterateFile(path: []const u8, comptime nArg: neededArg) []fileDescriptor {
    var vec = zlib.vector.CreateVec(fileDescriptor).init(nArg.allocator);
    defer vec.deinit();

    var dir = try std.Io.Dir.openDirAbsolute(nArg.io, path, .{});
    var iterator = dir.iterate(dir);

    var file: std.Io.File = undefined;
    var stat: std.Io.File.Stat = undefined;

    while (try iterator.next(nArg.io)) |entry| {
        file = std.Io.Dir.openFile(dir, nArg.io, entry.name, .{});
        stat = file.stat(nArg.io);

        vec.append(.{
            .name = nArg.allocator.dupe(u8, entry.name),
            .permission = .{
                .type = switch (entry.kind) {
                    .directory => 'd',
                    .sym_link => 'l',
                    .character_device => 'c',
                    .block_device => 'b',
                    .named_pipe => 'p',
                    .unix_domain_socket => 's',
                    .file => '.',
                    .unknown, .door, .event_port, .whiteout => '?',
                },
                .owner = .{
                    .execute = stat.permissions % 10,
                    .write = (stat.permissions / 10) % 10,
                    .read = ((stat.permissions / 10) / 10) % 10,
                },
            },
        });
    }

    return nArg.allocator.dupe(fileDescriptor, vec.items);
}

pub fn main(init: std.process.Init) !void {
    const nArg: neededArg = .{ .allocator = init.gpa, .io = init.io };
}
