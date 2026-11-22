const std = @import("std");
const zlib = @import("zlib");
const linux = std.os.linux;

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

const monthsIndex = [_][]const u8{ "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December" };

fn isLeapYear(year: u32) bool {
    return (@rem(year, 4) == 0 and @rem(year, 100) != 0) or (@rem(year, 400) == 0);
}

fn daysInMonth(month: u8, year: u32) u8 {
    return switch (month) {
        1 => 31,
        2 => if (isLeapYear(year)) 29 else 28,
        3 => 31,
        4 => 30,
        5 => 31,
        6 => 30,
        7 => 31,
        8 => 31,
        9 => 30,
        10 => 31,
        11 => 30,
        12 => 31,
        else => unreachable,
    };
}

fn unixTimestampToUTC(timestamp: u64) dateFormat {
    const MILLIS_PER_SEC = 1000;
    const SECS_PER_MIN = 60;
    const SECS_PER_HOUR = SECS_PER_MIN * 60;
    const SECS_PER_DAY = SECS_PER_HOUR * 24;

    const seconds = @divTrunc(timestamp, MILLIS_PER_SEC);

    // Compute the time of day.
    const hour: u5 = @intCast(@divTrunc(@rem(seconds, SECS_PER_DAY), SECS_PER_HOUR));
    const minute: u6 = @intCast(@divTrunc(@rem(seconds, SECS_PER_HOUR), SECS_PER_MIN));

    // Compute the date.
    var days = @divTrunc(seconds, SECS_PER_DAY);
    var year: u32 = 1970;

    while (true) {
        const days_in_year: u16 = if (isLeapYear(year)) 366 else 365;
        if (days >= days_in_year) {
            days -= days_in_year;
            year += 1;
        } else break;
    }

    var month: u8 = 1;
    while (true) {
        const day_of_month = daysInMonth(month, year);
        if (days >= day_of_month) {
            days -= day_of_month;
            month += 1;
        } else break;
    }

    const day: u5 = @intCast(days + 1);

    return .{
        .year = year,
        .month = monthsIndex[month],
        .day = day,
        .hour = hour,
        .minute = minute,
    };
}

pub fn resolvePath(dir: []const u8, name: []const u8, nArg: neededArg, kind: std.Io.File.Kind) ![]u8 {
    var tmp: [linux.PATH_MAX]u8 = undefined;
    const path = try nArg.allocator.print("{s}/{s}", .{ dir, name });
    if (kind == .sym_link) {
        const n = try std.Io.Dir.readLinkAbsolute(nArg.io, path, &tmp);
        return nArg.allocator.dupe(u8, tmp[0..n]);
    }
    return path;
}

pub fn iterateFile(path: []const u8, nArg: neededArg) ![]fileDescriptor {
    var vec = zlib.vector.CreateVec(fileDescriptor).init(nArg.allocator);
    defer vec.deinit();

    var dir = try std.Io.Dir.openDirAbsolute(nArg.io, path, .{ .iterate = true });
    defer dir.close(nArg.io);
    var iterator = dir.iterate();
    var file: std.Io.File = undefined;
    var stat: std.Io.File.Stat = undefined;
    var perm: u32 = undefined;
    var date: dateFormat = undefined;
    var statx: linux.Statx = undefined;
    var passwd: *std.c.passwd = undefined;

    while (try iterator.next(nArg.io)) |entry| {
        file = try std.Io.Dir.openFile(dir, nArg.io, entry.name, .{});
        defer file.close(nArg.io);
        stat = try file.stat(nArg.io);
        perm = stat.permissions.toMode();
        date = unixTimestampToUTC(@intCast(@divTrunc(stat.mtime.nanoseconds, 1_000_000)));
        _ = linux.statx(
            file.handle,
            "",
            linux.AT.EMPTY_PATH,
            .{ .UID = true, .GID = true },
            &statx,
        );
        passwd = std.c.getpwuid(statx.uid).?;

        _ = try vec.append(.{
            .name = try nArg.allocator.dupe(u8, entry.name),
            .permission = .{ .type = switch (entry.kind) {
                .directory => 'd',
                .sym_link => 'l',
                .character_device => 'c',
                .block_device => 'b',
                .named_pipe => 'p',
                .unix_domain_socket => 's',
                .file => '.',
                .unknown, .door, .event_port, .whiteout => '?',
            }, .owner = .{
                .read = @intCast((perm >> 6) & 0x4),
                .write = @intCast((perm >> 6) & 0x2),
                .execute = @intCast((perm >> 6) & 0x1),
            }, .group = .{
                .read = @intCast((perm >> 3) & 0x4),
                .write = @intCast((perm >> 3) & 0x2),
                .execute = @intCast((perm >> 3) & 0x1),
            }, .others = .{
                .read = @intCast((perm >> 0) & 0x4),
                .write = @intCast((perm >> 0) & 0x2),
                .execute = @intCast((perm >> 0) & 0x1),
            } },
            .date = date,
            .size = stat.size,
            .path = try resolvePath(path, entry.name, nArg, entry.kind),
            .owner = try nArg.allocator.dupe(u8, std.mem.span(passwd.name orelse "unknow")),
        });
    }

    return nArg.allocator.dupe(fileDescriptor, vec.items);
}

fn deinitFD(fds: []fileDescriptor, nArg: neededArg) void {
    for (fds) |f| {
        std.log.debug("Name: {s}, owner: {s}, path: {s}", .{ f.name, f.owner, f.path });
        nArg.allocator.free(f.name);
        nArg.allocator.gpa.free(f.owner);
        nArg.allocator.gpa.free(f.path);
    }
    nArg.allocator.gpa.free(fds);
}

fn isPath(path: []const u8, nArg: neededArg) struct { exist: bool, realpath: ?[]u8 } {
    var dir = std.Io.Dir.openDirAbsolute(nArg.io, path, .{}) catch |err| switch (err) {
        .FileNotFound => return .{ .exist = false, .realpath = null },
    };

    const buffer: [linux.PATH_MAX]u8 = undefined;
    const size = dir.realPath(nArg.io, buffer);
    return .{ .exist = true, .realpath = nArg.allocator.dupe(u8, buffer[0..size]) };
}

//pub fn formatFDS(fds: []fileDescriptor) void {}

pub fn main(init: std.process.Init) !void {
    const NA = neededArg{ .allocator = init.gpa, .io = init.io };
    const italloc = try init.minimal.args.iterateAllocator(init.gpa);
    var pathVec = zlib.vector.CreateVec([]const u8).init(init.gpa);
    var argVec = zlib.vector.CreateVec([]const u8).init(init.gpa);
    var fdsVec = zlib.vector.CreateVec([]fileDescriptor).init(init.gpa);
    defer italloc.deinit();
    // pour prendre tout les args
    _ = italloc.skip();
    while (italloc.next()) |arg| {
        const tmparg = std.mem.span(arg);
        const testpath = isPath(tmparg, NA);
        defer init.gpa.free(testpath.realpath);
        if (testpath.exist) {
            if (std.mem.endsWith(u8, testpath.realpath.?, "/")) {
                _ = try pathVec.append(testpath.realpath.?[0 .. testpath.realpath.?.len - 1]);
                continue;
            }
            _ = try pathVec.append(testpath.realpath.?);
        } else if (std.mem.startsWith(u8, tmparg, "-")) {
            _ = try argVec.append(tmparg[1..]);
        }
    }
    // pour la commande seule, genre juste `zlist`
    if (pathVec.length() == 0) {
        var actualdir = std.Io.Dir.cwd();
        defer actualdir.close(init.io);
        const buff: [linux.PATH_MAX]u8 = undefined;
        const size = actualdir.realPath(init.io, buff);
        _ = try pathVec.append(buff[0..size]);
    }
    //
    for (pathVec.items) |path| {
        _ = try fdsVec.append(iterateFile(path, NA));
    }
}
