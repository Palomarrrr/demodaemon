const std = @import("std");
const os = std.os;
const fmt = std.fmt;
const heap = std.heap;
const fs = std.fs;

pub const ArgErr = error{
    ArgVNotProvided,
    InvalidFormatChar,
    InputDirectoryNotProvided,
    OutputDirectoryNotProvided,
    InvalidCMDFlag,
};

pub const Args = struct {
    in_dir: []u8, // directory to watch for demos
    out_dir: []u8, // directory to move the demo to
    fmtstr: []u8,
    tout: u64, // Timeout to save demo once it has stopped recording
};

inline fn DetermineFlag(flag: [*:0]u8) !u3 {
    var itr: usize = 0;
    while (flag[itr] != 0) : (itr += 1) {
        switch (flag[itr]) {
            '-' => {
                continue;
            },
            'i' => {
                return 0b001;
            },
            'o' => {
                return 0b010;
            },
            't' => {
                return 0b011;
            },
            'f' => {
                return 0b100;
            },
            'h' => {
                std.debug.print("Demodaemon: A tiny, shitty, (and currently linux only), TF2 Demo manager!\n\nNormal usage | demoman -i /path/to/steam/tf/demos -o /path/to/output -t <delay time in seconds> -f <naming format>\n\n", .{});
                std.debug.print("-i /path/to/dir/\t| Path to input directory\n", .{});
                std.debug.print("-o /path/to/dir/\t| Path to output directory\n", .{});
                std.debug.print("-t <seconds>\t\t| Delay between directory scans/file moves\n", .{});
                std.debug.print("-f <formatString>\t| File name formatting\n", .{});
                std.debug.print("\n\tp | Player name\n", .{});
                std.debug.print("\tm | Map name\n", .{});
                std.debug.print("\ts | Server name\n", .{});
                std.debug.print("\tT | Time spent recording (in seconds)\n", .{});
                std.debug.print("\tt | Time spent recording (in ticks)\n", .{});
                std.debug.print("\tf | Time spent recording (in frames)\n", .{});
                std.debug.print("\tS | Time stamp of when the demo was started\n", .{});
                std.debug.print("\tD | Date stamp of when the demo was started\n", .{});
                std.debug.print("\tH | Hash of the demo header\n", .{});
                std.debug.print("\tExample | -f pmSD\n\n", .{});

                os.exit(0);
            },
            else => {
                return ArgErr.InvalidCMDFlag;
            },
        }
    }
    return 0b000;
}

pub fn ParseArgs(argv: [][*:0]u8) !*Args {
    if (argv.len < 2) return ArgErr.ArgVNotProvided;
    var flag: u3 = 0x0;

    var emptystr = [_]u8{0}; // WHY CANT I JUST CHECK IF A VALUE IS UNDEFINED AAAAAAAAAAAAAA

    var args: *Args = try heap.raw_c_allocator.create(Args);

    args.out_dir = &emptystr;
    args.in_dir = &emptystr;
    args.fmtstr = &emptystr;
    args.tout = 1;

    for (argv[1..argv.len]) |arg| {
        var arg_len: usize = 0;
        while (arg[arg_len] != 0) : (arg_len += 1) {} // Count the length of arg
        switch (flag) {
            0x1 => blk: { // Input file
                if (arg[arg_len - 1] == '/') arg_len -= 1; // Cut this if included
                args.in_dir = try heap.raw_c_allocator.alloc(u8, arg_len);
                for (arg, 0..arg_len) |c, i| args.in_dir[i] = c;
                flag = 0; // Reset
                break :blk;
            },
            0x2 => blk: { // Output file
                if (arg[arg_len - 1] == '/') arg_len -= 1; // Cut this if included
                args.out_dir = try heap.raw_c_allocator.alloc(u8, arg_len);
                for (arg, 0..arg_len) |c, i| args.out_dir[i] = c;
                flag = 0; // Reset
                break :blk;
            },
            0x3 => blk: { // Time delay
                var fuck_nullterms = try heap.raw_c_allocator.alloc(u8, arg_len);
                for (arg, 0..arg_len) |c, i| fuck_nullterms[i] = c;
                args.tout = try fmt.parseUnsigned(u64, fuck_nullterms, 10);
                flag = 0; // Reset
                break :blk;
            },
            0x4 => blk: {
                args.fmtstr = try heap.raw_c_allocator.alloc(u8, arg_len);
                for (arg, 0..arg_len) |c, i| {
                    switch (c) {
                        'H', 's', 'p', 'm', 'g', 'T', 't', 'f', 'S', 'D' => args.fmtstr[i] = c,
                        else => return ArgErr.InvalidFormatChar,
                    }
                }
                flag = 0;
                break :blk;
            },
            else => blk: {
                if (arg[0] == '-') flag = DetermineFlag(arg) catch {
                    return ArgErr.InvalidCMDFlag;
                };
                break :blk;
            },
        }
    }

    if (args.fmtstr[0] == 0) {
        args.fmtstr = @constCast("pmD");
    }
    // TODO Make these check if an env var is set with the directory
    if (args.out_dir[0] == 0) {
        return ArgErr.OutputDirectoryNotProvided;
    }
    if (args.in_dir[0] == 0) {
        return ArgErr.InputDirectoryNotProvided;
    }
    return args;
}
