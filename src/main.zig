const std = @import("std");
const mem = std.mem;
const io = std.io;
const print = std.debug.print;

const Blake2b = std.crypto.hash.blake2.Blake2b512;
const Error = error.Invalid;
const VERSION: []const u8 = "0.3.0";

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
    const chars: []const u8 = "c";
    const num_bytes: []const u8 = "n";
};

fn exit(code: Exit) noreturn {
    std.os.exit(@enumToInt(code));
}

const Opts = struct {
    length: usize = 32,
    alphabet: []const u8 = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789",
    key: ?[]const u8 = null,
    chars: []const u8 = "",
    num_bytes: usize = 0,
};

fn getOpts(allocator: *mem.Allocator) !Opts {
    var args = std.process.args();
    const prog_name = try (args.next(allocator) orelse return Error);
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
            const length_str = try (args.next(allocator) orelse return Error);
            defer allocator.free(length_str);
            opts.length = try std.fmt.parseInt(usize, length_str, 10);
        } else if (mem.eql(u8, flag, Flag.alphabet)) {
            opts.alphabet = try (args.next(allocator) orelse return Error);
        } else if (mem.eql(u8, flag, Flag.key)) {
            opts.key = try (args.next(allocator) orelse return Error);
        } else if (mem.eql(u8, flag, Flag.chars)) {
            opts.chars = try (args.next(allocator) orelse return Error);
        } else if (mem.eql(u8, flag, Flag.num_bytes)) {
            const num_bytes_str = try (args.next(allocator) orelse return Error);
            defer allocator.free(num_bytes_str);
            opts.num_bytes = try std.fmt.parseInt(usize, num_bytes_str, 10);
        } else {
            printUsage(prog_name);
            exit(.usage);
        }
    }
    if (opts.length == 0 or opts.length > Blake2b.digest_length) {
        print("length must be greater than zero and max {d}", .{Blake2b.digest_length});
        exit(.usage);
    }
    if (opts.alphabet.len == 0 or opts.alphabet.len + opts.chars.len > 256) {
        print("alphabet must be greater than zero and alphabet plus chars must be less than 256", .{});
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
        \\{[exe]s} [-{[h]s}{[V]s}] [-{[l]s} NUM] [-{[a]s} STR] [-{[k]s} STR] [-{[c]s} STR] [-{[n]s} NUM]
        \\
        \\[-{[h]s}] * Print help and exit
        \\[-{[V]s}] * Print version and exit
        \\
        \\[-{[l]s}] * Length of password (default: 32)
        \\[-{[a]s}] * Alphabet (default: abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789)
        \\[-{[k]s}] * Key (default: null)
        \\[-{[c]s}] * Additional chars (default: "")
        \\[-{[n]s}] * Number of bytes to read (default: 0 = all)
    ;
    print(usage, .{
        .exe = std.fs.path.basename(exe),
        .h = Flag.help,
        .V = Flag.version,
        .l = Flag.length,
        .a = Flag.alphabet,
        .k = Flag.key,
        .c = Flag.chars,
        .n = Flag.num_bytes,
    });
}

fn b2pw(reader: anytype, writer: anytype, opts: Opts) !void {
    var b2 = Blake2b.init(.{ .expected_out_bits = opts.length << 3, .key = opts.key });
    var buffer: [1 << 8]u8 = undefined;
    std.debug.assert(buffer.len >= Blake2b.digest_length);
    var buffer_slice: []u8 = buffer[0..];
    var num_bytes = opts.num_bytes;
    var i: usize = 0;
    while (true) {
        if (num_bytes != 0) {
            num_bytes -= i;
            if (num_bytes < buffer_slice.len) {
                buffer_slice = buffer_slice[0..num_bytes];
            }
        }
        i = try reader.readAll(buffer_slice);
        if (i == 0) {
            break;
        }
        b2.update(buffer_slice[0..i]);
    }
    b2.final(buffer[0..Blake2b.digest_length]);
    var alphabet: [256]u8 = undefined;
    for (opts.alphabet) |c, j| {
        alphabet[j] = c;
    }
    for (opts.chars) |c, j| {
        alphabet[j + opts.alphabet.len] = c;
    }
    const alphabet_len = opts.alphabet.len + opts.chars.len;
    for (buffer[0..opts.length]) |v| {
        try writer.writeByte(alphabet[v % alphabet_len]);
    }
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const opts = try getOpts(&arena.allocator);
    const stdin = io.getStdIn();
    const stdout = io.getStdOut();
    try b2pw(stdin.reader(), stdout.writer(), opts);
}

test "b2pw" {
    const TestVector = struct {
        input: []const u8,
        output: []const u8,
    };
    const test_vectors = [_]TestVector{
        .{ .input = "test1", .output = "RQ3sDNrPzzkiVLYsqRzsnQTkgbK4cm0U" },
        .{ .input = "test2", .output = "KS4qquoEFhN4XJiECDcQZxJXca6ZrKCN" },
    };
    for (test_vectors) |v| {
        var buffer: [Blake2b.digest_length]u8 = undefined;
        const reader = io.fixedBufferStream(v.input).reader();
        const writer = io.fixedBufferStream(&buffer).writer();
        const opts = Opts{ .length = v.output.len };
        try b2pw(reader, writer, opts);
        try std.testing.expectEqualSlices(u8, v.output, buffer[0..opts.length]);
    }
}
