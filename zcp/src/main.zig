const std = @import("std");
const zlib = @import("zlib");

const neededArg = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
};

const minimalFile = struct {
    content: []const u8,
    destpath: []const u8,
};

fn isDir(path: []const u8, nArg: neededArg) bool {
    const dir = std.Io.Dir.cwd().openDir(nArg.io, path, .{}) catch {
        return false;
    };
    dir.close(nArg.io);
    return true;
}

fn extractName(path: []const u8) []const u8 {
    return ret: {
        if (std.mem.findScalarLast(u8, path, '/')) |v| {
            break :ret path[v + 1 ..];
        }
        break :ret path;
    };
}

fn deinitFile(mfs: []minimalFile, nArg: neededArg) void {
    for (mfs) |mf| {
        nArg.allocator.free(mf.content);
        nArg.allocator.free(mf.destpath);
    }
}

pub fn main(init: std.process.Init) !void {
    const NA = neededArg{ .allocator = init.gpa, .io = init.io };
    var argsVec = zlib.vector.CreateVec([]const u8).init(NA.allocator);
    var fileVec = zlib.vector.CreateVec(minimalFile).init(NA.allocator);

    defer fileVec.deinit();
    defer deinitFile(fileVec.items, NA);
    defer argsVec.deinit();
    var dest: zlib.string.string = try .init(NA.allocator, "<NULL_PATH>");
    defer dest.deinit();
    zlib.fs._init(init.io, init.gpa);

    var itargs = init.minimal.args.iterate();
    _ = itargs.skip();
    while (itargs.next()) |arg| {
        _ = try argsVec.append(arg);
    }
    const alenght = argsVec.length();
    for (argsVec.items, 0..) |itm, idx| {
        if (!isDir(itm, NA)) continue;
        try dest.rewriteAlloc(try argsVec.getValue(idx));
        try argsVec.resize(idx);
        break;
    }
    if (!dest.endswith("/")) try dest.cat("/");
    if (alenght == argsVec.length()) {
        std.log.err("No dest found", .{});
        std.process.exit(1);
    }
    for (argsVec.items) |file| {
        _ = try fileVec.append(.{
            .content = try zlib.fs.File.readFile(file, null),
            .destpath = try NA.allocator.print("{s}{s}", .{ dest.get(), extractName(file) }),
        });
    }
    for (fileVec.items) |file| {
        if (!zlib.fs.File.ifExist(file.destpath)) _ = try zlib.fs.File.createFile(file.destpath, .{});
        try zlib.fs.File.writeFile(file.destpath, file.content);
    }
}
