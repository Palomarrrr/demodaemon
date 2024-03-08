const std = @import("std");
const heap = std.heap;
const fmt = std.fmt;
const os = std.os;
const fs = std.fs;
const io = std.io;

const Args = @import("./args.zig");
const DirWatcher = @import("./dirwatcher.zig");

pub fn main() !void {
    const arg_ret: *Args.Args = Args.ParseArgs(os.argv) catch |err| {
        std.debug.print("\x1b[1;31m[DEMODAEMON]\x1b[0m ERROR: ", .{});
        switch (err) {
            Args.ArgErr.InvalidCMDFlag => std.debug.print("Invalid command flag provided\n", .{}),
            //Args.ArgErr.ArgVNotProvided => std.debug.print("No args provided. Use -h for usage flags\n", .{}),
            Args.ArgErr.InvalidFormatChar => std.debug.print("Invalid format char provided\n", .{}),
            Args.ArgErr.InputDirectoryNotProvided => std.debug.print("No demo input directory provided\n", .{}),
            Args.ArgErr.OutputDirectoryNotProvided => std.debug.print("No demo output directory provided\n", .{}),
            else => unreachable,
        }
        std.debug.print("For usage information, try 'demodaemon -h'\n", .{});
        os.exit(1);
    };

    std.debug.print("\x1b[1;32m[DEMODAEMON]\x1b[0m Starting up...\n", .{});

    var dwatch: *DirWatcher.DirWatcher = try heap.raw_c_allocator.create(DirWatcher.DirWatcher);
    dwatch.create(arg_ret.in_dir, arg_ret.out_dir, arg_ret.tout) catch {
        os.exit(4);
    };
    std.debug.print("\x1b[1;32m[DEMODAEMON]\x1b[0m Watching {s} for '.dem' files...\n", .{dwatch.dir_str_in});
    while (true) {
        var file_str = try dwatch.check() orelse {
            std.time.sleep(std.time.ns_per_s * dwatch.tout);
            continue;
        };

        if (std.ascii.eqlIgnoreCase(file_str[file_str.len - 4 .. file_str.len], ".dem")) { // Make sure we're looking at a demo file
            std.debug.print("\x1b[1;32m[DEMODAEMON]\x1b[0m Found demo file {s}\n[DEMODAEMON] Waiting {} seconds to move the file...\n", .{ file_str, dwatch.tout });
            std.time.sleep(std.time.ns_per_s * dwatch.tout);
            dwatch.moveToOutputDir(file_str, arg_ret.fmtstr) catch {
                os.exit(5);
            };
            std.debug.print("\x1b[1;32[DEMODAEMON]\x1b[0m File {s} has been moved to the output directory!\n", .{file_str});
        } else std.time.sleep(std.time.ns_per_s * dwatch.tout);
    }
    dwatch.destroy();
}
