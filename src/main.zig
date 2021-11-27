const std = @import("std");
const mem = std.mem;
const io = std.io;
const os = std.os;
const path = std.fs.path;
const print = std.debug.print;
const process = std.process;

const Blake2b256 = std.crypto.hash.blake2.Blake2b256;
const VERSION: []const u8 = "0.1.0";

const Exit = enum(u8) {
    success = 0,
};

const Flag = struct {
    const help: []const u8 = "h";
    const version: []const u8 = "V";
};

fn exit(code: Exit) noreturn {
    os.exit(@enumToInt(code));
}

fn getOpts(allocator: *mem.Allocator) !void {
    var args = process.args();
    var prog_name = try (args.next(allocator) orelse return error.Invalid);
    defer allocator.free(prog_name);
    while (args.next(allocator)) |arg_or_err| {
        const arg = try arg_or_err;
        defer allocator.free(arg);
        const flag = arg[1..];
        if (mem.eql(u8, flag, Flag.help)) {
            printUsage(prog_name);
            exit(.success);
        } else if (mem.eql(u8, flag, Flag.version)) {
            print("{s}", .{VERSION});
            exit(.success);
        }
        return error.Invalid;
    }
}

fn printUsage(exe: []const u8) void {
    const usage =
        \\{[exe]s} [-{[h]s}|{[V]s}]
        \\
        \\[-{[h]s}] * Print help and exit
        \\[-{[V]s}] * Print version and exit
    ;
    print(usage, .{ .exe = path.basename(exe), .h = Flag.help, .V = Flag.version });
}

fn b2pw(reader: anytype, writer: anytype) !void {
    var b2 = Blake2b256.init(.{});
    var buffer: [Blake2b256.digest_length]u8 = undefined;
    var i = try reader.readAll(&buffer);
    b2.update(&buffer);
    while (i == buffer.len) : (i = try reader.readAll(&buffer)) {
        b2.update(&buffer);
    }
    b2.final(&buffer);
    const map = [_]u8{
        'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z',
        'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
        '0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
    };
    for (buffer) |v| {
        try writer.writeByte(map[v % map.len]);
    }
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    try getOpts(&arena.allocator);
    var stdin = io.getStdIn();
    var stdout = io.getStdOut();
    try b2pw(stdin.reader(), stdout.writer());
}

test "b2pw" {
    const TestVector = struct {
        input: []const u8,
        output: []const u8,
    };
    const test_vectors = [_]TestVector{
        .{ .input = "test1", .output = "VhVsUo7wevh7ZjEHRxrGrOgo0iKJ7HSL" },
        .{ .input = "test2", .output = "PrJEtKpcPLjjdcbvAw5Gvo9IDsZBOSqr" },
    };
    for (test_vectors) |v| {
        var buffer: [Blake2b256.digest_length]u8 = undefined;
        const reader = io.fixedBufferStream(v.input).reader();
        const writer = io.fixedBufferStream(&buffer).writer();
        try b2pw(reader, writer);
        try std.testing.expectEqualSlices(u8, v.output, &buffer);
    }
}
