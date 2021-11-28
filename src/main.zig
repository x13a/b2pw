const std = @import("std");
const mem = std.mem;
const io = std.io;
const print = std.debug.print;

const Blake2b = std.crypto.hash.blake2.Blake2b512;
const VERSION: []const u8 = "0.2.0";

const Exit = enum(u8) {
    success = 0,
    usage = 2,
};

const Flag = struct {
    const help: []const u8 = "h";
    const version: []const u8 = "V";
    const length: []const u8 = "l";
    const alphabet: []const u8 = "a";
    const key: []const u8 = "k";
};

fn exit(code: Exit) noreturn {
    std.os.exit(@enumToInt(code));
}

const Opts = struct {
    length: usize = 32,
    alphabet: []const u8 = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789",
    key: ?[]const u8 = null,
};

fn getOpts(allocator: *mem.Allocator) !Opts {
    var args = std.process.args();
    var prog_name = try (args.next(allocator) orelse return error.Invalid);
    defer allocator.free(prog_name);
    var opts = Opts{};
    while (args.next(allocator)) |arg_or_err| {
        const arg = try arg_or_err;
        defer allocator.free(arg);
        if (!mem.startsWith(u8, arg, "-")) {
            printUsage(prog_name);
            exit(.usage);
        }
        const flag = arg[1..];
        if (mem.eql(u8, flag, Flag.help)) {
            printUsage(prog_name);
            exit(.success);
        } else if (mem.eql(u8, flag, Flag.version)) {
            print("{s}", .{VERSION});
            exit(.success);
        } else if (mem.eql(u8, flag, Flag.length)) {
            const length_str = try (args.next(allocator) orelse return error.Invalid);
            defer allocator.free(length_str);
            opts.length = try std.fmt.parseInt(usize, length_str, 10);
        } else if (mem.eql(u8, flag, Flag.alphabet)) {
            opts.alphabet = try (args.next(allocator) orelse return error.Invalid);
        } else if (mem.eql(u8, flag, Flag.key)) {
            opts.key = try (args.next(allocator) orelse return error.Invalid);
        } else {
            return error.Invalid;
        }
    }
    if (opts.length == 0 or opts.length > Blake2b.digest_length) {
        print("length must be greater than zero and max {d}", .{Blake2b.digest_length});
        exit(.usage);
    }
    if (opts.alphabet.len == 0 or opts.alphabet.len > 256) {
        print("alphabet must be greater than zero and max 256", .{});
        exit(.usage);
    }
    if (opts.key) |v| {
        if (v.len > Blake2b.key_length_max) {
            print("key must be max {d}", .{Blake2b.key_length_max});
            exit(.usage);
        }
    }
    return opts;
}

fn printUsage(exe: []const u8) void {
    const usage =
        \\{[exe]s} [-{[h]s}|{[V]s}] [-{[l]s} NUM] [-{[a]s} STR] [-{[k]s} STR]
        \\
        \\[-{[h]s}] * Print help and exit
        \\[-{[V]s}] * Print version and exit
        \\
        \\[-{[l]s}] * Length of password (default: 32)
        \\[-{[a]s}] * Alphabet (default: abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789)
        \\[-{[k]s}] * Key (default: null)
    ;
    print(usage, .{
        .exe = std.fs.path.basename(exe),
        .h = Flag.help,
        .V = Flag.version,
        .l = Flag.length,
        .a = Flag.alphabet,
        .k = Flag.key,
    });
}

fn b2pw(reader: anytype, writer: anytype, opts: Opts) !void {
    var b2 = Blake2b.init(.{ .expected_out_bits = opts.length * 8, .key = opts.key });
    var buffer: [Blake2b.digest_length]u8 = undefined;
    var i = try reader.readAll(&buffer);
    while (i == buffer.len) : (i = try reader.readAll(&buffer)) {
        b2.update(&buffer);
    }
    b2.update(&buffer);
    b2.final(&buffer);
    var alphabet: [256]u8 = undefined;
    for (opts.alphabet) |v, j| {
        alphabet[j] = v;
    }
    for (buffer[0..opts.length]) |v| {
        try writer.writeByte(alphabet[v % opts.alphabet.len]);
    }
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const opts = try getOpts(&arena.allocator);
    var stdin = io.getStdIn();
    var stdout = io.getStdOut();
    try b2pw(stdin.reader(), stdout.writer(), opts);
}

test "b2pw" {
    const TestVector = struct {
        input: []const u8,
        output: []const u8,
    };
    const test_vectors = [_]TestVector{
        .{ .input = "test1", .output = "F8yzwWXFRDglUv1EETsT4tLe4ItUZ8Qd" },
        .{ .input = "test2", .output = "6EV9DkcE2jMbLRw02aNdRFoXtMkGFyTm" },
    };
    for (test_vectors) |v| {
        var buffer: [Blake2b.digest_length]u8 = undefined;
        const reader = io.fixedBufferStream(v.input).reader();
        const writer = io.fixedBufferStream(&buffer).writer();
        const opts = Opts{};
        try b2pw(reader, writer, opts);
        try std.testing.expectEqualSlices(u8, v.output, buffer[0..opts.length]);
    }
}
