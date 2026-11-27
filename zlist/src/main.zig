const std = @import("std");
const zlib = @import("zlib");
const colorp = @import("colored_print.zig");
const linux = std.os.linux;
// Go faire le tout premier Zcore utils (zcu): zlist (donc ls quoi)

// PCF: printingCF
// bruh par PUR hasard ca a fait aussi l'acronyme
// du Parti Communiste Français
// Mdrrrr

var lastDirPCF: zlib.string.string = undefined;
const NO_PATH: []const u8 = "NO_PATH";
var dotfile_allow: bool = false;
var countPerLine: i32 = 0;

const flagEnum = enum { DisplayPermission, DisplaySize, DisplayOwner, DisplayDate, DisplayPath, __HiddenEnum_AllocatedTuple };

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

const chosenFile = struct {
    name: []const u8,
    permission: ?permissionFile,
    size: ?usize,
    owner: ?[]const u8,
    date: ?dateFormat,
    path: []const u8,
};

pub fn defaultFD(nArg: neededArg) !fileDescriptor {
    return .{
        .name = try nArg.allocator.alloc(u8, 1),
        .permission = .{
            .type = '?',
            .owner = .{
                .read = 0,
                .write = 0,
                .execute = 0,
            },
            .group = .{
                .read = 0,
                .write = 0,
                .execute = 0,
            },
            .others = .{
                .read = 0,
                .write = 0,
                .execute = 0,
            },
        },
        .date = .{ .day = 0, .hour = 0, .minute = 0, .month = "", .year = 0 },
        .size = 0,
        .path = try nArg.allocator.alloc(u8, 1),
        .owner = try nArg.allocator.alloc(u8, 1),
    };
}

const monthsIndex = [_][]const u8{ "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December" };
// Juste pour la date cette partie...
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
        .month = monthsIndex[month - 1],
        .day = day,
        .hour = hour,
        .minute = minute,
    };
}
// Piou la date...

pub fn resolvePath(dir: []const u8, name: []const u8, nArg: neededArg, kind: std.Io.File.Kind) ![]u8 {
    var tmp: [linux.PATH_MAX]u8 = undefined;
    const path = try nArg.allocator.print("{s}/{s}", .{ dir, name });
    if (kind == .sym_link) {
        const n = try std.Io.Dir.readLinkAbsolute(nArg.io, path, &tmp);
        nArg.allocator.free(path);
        return nArg.allocator.dupe(u8, tmp[0..n]);
    }
    return path;
}

pub fn iterateFile(path: []const u8, nArg: neededArg) ![]fileDescriptor {
    var vec = zlib.vector.CreateVec(fileDescriptor).init(nArg.allocator);
    defer vec.deinit();

    var dir = try std.Io.Dir.cwd().openDir(nArg.io, path, .{ .iterate = true });
    defer dir.close(nArg.io);
    var iterator = dir.iterate();
    var file: std.Io.File = undefined;
    var stat: std.Io.File.Stat = undefined;
    var perm: u32 = undefined;
    var date: dateFormat = undefined;
    var statx: linux.Statx = undefined;
    var passwd: *std.c.passwd = undefined;

    while (try iterator.next(nArg.io)) |entry| {
        if (entry.name[0] == '.' and !dotfile_allow) continue;
        file = std.Io.Dir.openFile(dir, nArg.io, entry.name, .{}) catch {
            _ = try vec.append(try defaultFD(nArg));
            continue;
        };
        defer file.close(nArg.io);
        errdefer file.close(nArg.io);
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

    return vec.getAllElementsDupe();
}

fn deinitFD(fds: []fileDescriptor, nArg: neededArg) void {
    for (fds) |f| {
        nArg.allocator.free(f.name);
        nArg.allocator.free(f.owner);
        nArg.allocator.free(f.path);
    }
    //nArg.allocator.free(fds);
}

fn corespondByte(byte: *u8) void {
    if (byte.* == 4) {
        byte.* = 'r';
    } else if (byte.* == 2) {
        byte.* = 'w';
    } else if (byte.* == 1) {
        byte.* = 'x';
    } else {
        byte.* = '-';
    }
}

pub fn formatFDS(fd: *fileDescriptor) void {
    inline for (@typeInfo(@TypeOf(fd.permission)).@"struct".field_names) |perm_name| {
        if (@TypeOf(@field(fd.permission, perm_name)) == u8) continue;
        inline for (@typeInfo(@TypeOf(@field(fd.permission, perm_name))).@"struct".field_names) |byte_name| {
            corespondByte(&@field(@field(fd.permission, perm_name), byte_name));
        }
    }
}

pub fn choseFD(fd: *const fileDescriptor, nArg: neededArg, flags: []flagEnum) chosenFile {
    var cf: chosenFile = .{
        .name = fd.name,
        .date = null,
        .owner = null,
        .path = fd.path,
        .permission = null,
        .size = null,
    };
    var b = false;
    for (0..flags.len) |i| {
        if (@TypeOf(flags[i]) != flagEnum) continue;
        switch (flags[i]) {
            flagEnum.DisplayDate => cf.date = fd.date,
            flagEnum.DisplayOwner => cf.owner = fd.owner,
            flagEnum.DisplayPermission => cf.permission = fd.permission,
            flagEnum.DisplaySize => cf.size = fd.size,
            flagEnum.__HiddenEnum_AllocatedTuple => b = true,
            else => continue,
        }
    }
    if (b) nArg.allocator.free(flags);
    return cf;
}

// Zlist |>
// -d = display date
// -o = display owner
// -p = display path
// -P = display permission
// -s = display size
// -a = dotfile allow

pub fn extractFlag(flgs: [][]const u8, nArg: neededArg) ![]flagEnum {
    var vec = zlib.vector.CreateVec(flagEnum).init(nArg.allocator);
    defer vec.deinit();
    _ = try vec.append(flagEnum.__HiddenEnum_AllocatedTuple);
    for (flgs) |f| {
        for (f) |byte| {
            switch (byte) {
                'd' => _ = try vec.append(flagEnum.DisplayDate),
                'o' => _ = try vec.append(flagEnum.DisplayOwner),
                'p' => _ = try vec.append(flagEnum.DisplayPermission),
                's' => _ = try vec.append(flagEnum.DisplaySize),
                else => continue,
            }
        }
    }
    return vec.getAllElementsDupe();
}

// Aller... last function

pub fn printingCF(cf: chosenFile, nArg: neededArg) !void {
    if (!lastDirPCF.compare(extractDir(cf.path)) and !std.mem.eql(u8, extractDir(cf.path), "NO_PATH")) {
        try colorp.cprintn("\n{s}:", colorp.RED, nArg.allocator, .{extractDir(cf.path)});
        try lastDirPCF.rewriteAlloc(extractDir(cf.path));
    }
    var Fperline = true;

    if (cf.permission) |perm| {
        try colorp.cprint("{c}", switch (perm.type) {
            '.' => colorp.GREY,
            else => colorp.BLUE,
        }, nArg.allocator, .{perm.type});

        try colorp.cprint("{c}", switch (perm.owner.read) {
            '-' => colorp.GREY,
            else => colorp.YELLOW,
        }, nArg.allocator, .{perm.owner.read});
        try colorp.cprint("{c}", switch (perm.owner.write) {
            '-' => colorp.GREY,
            else => colorp.RED,
        }, nArg.allocator, .{perm.owner.write});
        try colorp.cprint("{c}", switch (perm.owner.execute) {
            '-' => colorp.GREY,
            else => colorp.GREEN,
        }, nArg.allocator, .{perm.owner.execute});

        try colorp.cprint("{c}", switch (perm.group.read) {
            '-' => colorp.GREY,
            else => colorp.YELLOW,
        }, nArg.allocator, .{perm.group.read});
        try colorp.cprint("{c}", switch (perm.group.write) {
            '-' => colorp.GREY,
            else => colorp.RED,
        }, nArg.allocator, .{perm.group.write});
        try colorp.cprint("{c}", switch (perm.group.execute) {
            '-' => colorp.GREY,
            else => colorp.GREEN,
        }, nArg.allocator, .{perm.group.execute});

        try colorp.cprint("{c}", switch (perm.others.read) {
            '-' => colorp.GREY,
            else => colorp.YELLOW,
        }, nArg.allocator, .{perm.others.read});
        try colorp.cprint("{c}", switch (perm.others.write) {
            '-' => colorp.GREY,
            else => colorp.RED,
        }, nArg.allocator, .{perm.others.write});
        try colorp.cprint("{c} ", switch (perm.others.execute) {
            '-' => colorp.GREY,
            else => colorp.GREEN,
        }, nArg.allocator, .{perm.others.execute});

        Fperline = false;
    }
    if (cf.size) |size| {
        try colorp.cprint("{d} ", colorp.GREEN, nArg.allocator, .{size});
        Fperline = false;
    }
    if (cf.owner) |owner| {
        try colorp.cprint("{s} ", colorp.YELLOW, nArg.allocator, .{owner});
        Fperline = false;
    }
    if (cf.date) |date| {
        try colorp.cprint("{d} {s} {d} at {d}:{d} ", colorp.BLUE, nArg.allocator, .{
            date.day,
            date.month,
            date.year,
            date.hour,
            date.minute,
        });
        Fperline = false;
    }
    if (Fperline and countPerLine < 3) {
        try colorp.cprint("{s} ", colorp.ORANGE, nArg.allocator, .{cf.name});
        countPerLine += 1;
    } else {
        try colorp.cprintn("{s}", colorp.ORANGE, nArg.allocator, .{cf.name});
        countPerLine = 0;
    }
}

fn extractDir(path: []const u8) []const u8 {
    if (std.mem.findScalarLast(u8, path, '/')) |i| {
        return path[0..i];
    }
    return NO_PATH;
}

fn isPath(path: []const u8, nArg: neededArg) !struct { exist: bool, realpath: ?[]u8 } {
    var dir = std.Io.Dir.cwd().openDir(nArg.io, path, .{}) catch |err| switch (err) {
        error.FileNotFound => return .{ .exist = false, .realpath = null },
        else => unreachable,
    };

    var buffer: [linux.PATH_MAX]u8 = undefined;
    const size = try dir.realPath(nArg.io, &buffer);
    return .{ .exist = true, .realpath = try nArg.allocator.dupe(u8, buffer[0..size]) };
}

fn printHelp() void {
    std.debug.print(
        \\ Zlist |>
        \\ -d = display date
        \\ -o = display owner
        \\ -p = display permission
        \\ -s = display size
        \\ -a = dotfile allow
    , .{});
    std.debug.print("\n", .{});
}

pub fn main(init: std.process.Init) !void {
    const NA = neededArg{ .allocator = init.gpa, .io = init.io };
    var italloc = try init.minimal.args.iterateAllocator(NA.allocator);
    var pathVec = zlib.vector.CreateVec([]const u8).init(NA.allocator);
    var argVec = zlib.vector.CreateVec([]const u8).init(NA.allocator);
    var fdsVec = zlib.vector.CreateVec([]fileDescriptor).init(NA.allocator);
    var cfsVec = zlib.vector.CreateVec(chosenFile).init(NA.allocator);
    lastDirPCF = try .init(NA.allocator, "<NULL>");

    defer lastDirPCF.deinit();
    defer pathVec.deinit();
    defer argVec.deinit();
    defer fdsVec.deinit();
    defer italloc.deinit();
    defer cfsVec.deinit();
    // pour prendre tout les args
    _ = italloc.skip();
    while (italloc.next()) |arg| {
        if (std.mem.eql(u8, arg, "--help")) {
            printHelp();
            std.process.exit(0);
        }
        const testpath = try isPath(arg, NA);
        defer {
            if (testpath.realpath) |rp| {
                NA.allocator.free(rp);
            }
        }
        if (testpath.exist) {
            if (std.mem.endsWith(u8, testpath.realpath.?, "/")) {
                _ = try pathVec.append(testpath.realpath.?[0 .. testpath.realpath.?.len - 1]);
                continue;
            }
            _ = try pathVec.append(testpath.realpath.?);
        } else if (std.mem.startsWith(u8, arg, "-")) {
            _ = try argVec.append(arg[1..]);
            if (std.mem.findScalar(u8, arg, 'a') != null) dotfile_allow = true;
        }
    }
    // pour la commande seule, genre juste `zlist`
    if (pathVec.length() == 0) {
        var actualdir = std.Io.Dir.cwd();
        var buff: [linux.PATH_MAX]u8 = undefined;
        const size = try actualdir.realPath(init.io, &buff);
        _ = try pathVec.append(buff[0..size]);
    }
    // vector de tableaux, son
    for (pathVec.items) |path| {
        const tmp = try iterateFile(path, NA);
        _ = try fdsVec.appendNoAlloc(tmp);
    }
    for (fdsVec.items) |*fds| {
        for (fds.*) |*fdss| {
            formatFDS(fdss);
            _ = try cfsVec.append(choseFD(fdss, NA, try extractFlag(argVec.items, NA)));
        }
    }

    for (cfsVec.items) |cf| {
        try printingCF(cf, NA);
    }
    std.debug.print("\n", .{});

    for (fdsVec.items) |fds| {
        deinitFD(fds, NA);
    }
}
