const std = @import("std");
const fs = std.fs;
const os = std.os;
const fmt = std.fmt;
const heap = std.heap;
const mem = std.mem;
const utf = std.unicode;
const hash = std.hash;
const time = std.time;

const args = @import("./args.zig");

const FmtErr = error{
    InvalidFormatArg,
};

pub const DirWatcher = struct {
    dir_str_in: []u8,
    dir_str_out: []u8,
    dir_in: fs.Dir,
    dir_out: fs.Dir,
    tout: u64,

    pub fn create(self: *DirWatcher, dir_str_in: []const u8, dir_str_out: []const u8, tout: u64) !void {
        // WARNING: THIS IS DEPRECATED IN RELEASES OF ZIG PAST 0.11.0!!!
        self.dir_in = fs.openDirAbsolute(dir_str_in, .{ .access_sub_paths = true, .no_follow = true, .iterate = true }) catch |err| {
            switch (err) {
                fs.Dir.OpenError.BadPathName => std.debug.print("\x1b[1;31m[DEMODAEMON]\x1b[0m ERROR: Directory `{s}` does not exist\n", .{dir_str_in}),
                fs.Dir.OpenError.AccessDenied => std.debug.print("\x1b[1;31m[DEMODAEMON]\x1b[0m ERROR: You do not have permission to access directory `{s}`\n", .{dir_str_in}),
                else => std.debug.print("\x1b[1;31m[DEMODAEMON]\x1b[0m ERROR: Something unexpected happened when accessing `{s}`\nReport this for help: {any}\n", .{ dir_str_in, err }),
            }
            return err;
        };
        self.dir_out = fs.openDirAbsolute(dir_str_out, .{ .access_sub_paths = true, .no_follow = true, .iterate = true }) catch |err| {
            switch (err) {
                fs.Dir.OpenError.BadPathName => std.debug.print("\x1b[1;31m[DEMODAEMON]\x1b[0m ERROR: Directory `{s}` does not exist\n", .{dir_str_out}),
                fs.Dir.OpenError.AccessDenied => std.debug.print("\x1b[1;31m[DEMODAEMON]\x1b[0m ERROR: You do not have permission to access directory `{s}`\n", .{dir_str_out}),
                else => std.debug.print("\x1b[1;31m[DEMODAEMON]\x1b[0m ERROR: Something unexpected happened when accessing `{s}`\nReport this for help: {any}\n", .{ dir_str_out, err }),
            }
            return err;
        };

        // Copy the directory string over
        self.dir_str_in = try heap.raw_c_allocator.alloc(u8, dir_str_in.len);
        for (dir_str_in, 0..dir_str_in.len) |c, i| {
            self.dir_str_in[i] = c;
        }
        self.dir_str_out = try heap.raw_c_allocator.alloc(u8, dir_str_out.len);
        for (dir_str_out, 0..dir_str_out.len) |c, i| {
            self.dir_str_out[i] = c;
        }

        self.tout = tout;
    }

    pub fn destroy(self: *DirWatcher) void {
        self.dir_in.close(); // Close the directories
        self.dir_out.close();

        heap.raw_c_allocator.free(self.dir_str_in); // Free the dir strings
        heap.raw_c_allocator.free(self.dir_str_out);
    }

    pub fn check(self: *DirWatcher) !?[]u8 {
        var walker = try self.dir_in.walk(heap.raw_c_allocator);
        defer walker.deinit();

        while (true) {
            const entry = walker.next() catch {
                return null;
            } orelse return null; // gotta deal with the mf "!?"

            if (entry.kind == std.fs.File.Kind.file) { // Make sure were dealing with files, not directories
                const rets = try mem.concat(heap.raw_c_allocator, u8, &[_][]u8{ self.dir_str_in, @constCast("/"), @constCast(entry.path) });
                return rets;
            }
        }
    }

    pub fn moveToOutputDir(self: *DirWatcher, file_str: []const u8, fmtstr: []u8) !void {
        var new_file_name: []u8 = createFileName(file_str, fmtstr) catch |err| {
            //std.debug.print("\x1b[1;31m[DEMODAEMON]\x1b[0m ERROR: ", .{});
            //switch (err) {
            //    fs.File.OpenError.AccessDenied => std.debug.print("You do not have permission to write files in directory `{s}`\n", .{self.*.dir_str_out}),
            //    fs.File.OpenError.PathAlreadyExists => std.debug.print("File `{s}` already exists...\n", .{new_file_name}),
            //    else => std.debug.print("\x1b[1;31m[DEMODAEMON]\x1b[0m ERROR: Something unexpected happened when accessing `{s}`\nReport this for help: {any}\n", .{ dir_str_out, err }),
            //}
            return err;
        };
        const new_file_str: []u8 = try mem.concat(heap.raw_c_allocator, u8, &[_][]u8{ self.dir_str_out, @constCast("/"), new_file_name[0 .. new_file_name.len - 1], @constCast(".dem") });
        const old_file_str: []u8 = try mem.concat(heap.raw_c_allocator, u8, &[_][]u8{ self.dir_str_in, @constCast("/"), new_file_name, @constCast(".dem") });
        os.rename(file_str, old_file_str) catch |err| {
            std.debug.print("\x1b[1;31m[DEMODAEMON]\x1b[0m ERROR: ", .{});
            switch (err) {
                os.RenameError.AccessDenied => std.debug.print("You do not have permission to write files in directory `{s}`\n", .{self.*.dir_str_in}),
                os.RenameError.PathAlreadyExists => std.debug.print("File `{s}` already exists...\n", .{old_file_str}),
                os.RenameError.NameTooLong => std.debug.print("File name `{s}` is too long\n", .{old_file_str}),
                else => std.debug.print("Something unexpected happened when accessing the file\nReport this for help: {any}\n", .{err}),
            }
            return err;
        };
        os.rename(old_file_str, new_file_str) catch |err| {
            std.debug.print("\x1b[1;31m[DEMODAEMON]\x1b[0m ERROR: ", .{});
            switch (err) {
                os.RenameError.AccessDenied => std.debug.print("You do not have permission to write files in directory `{s}`\n", .{self.*.dir_str_out}),
                os.RenameError.PathAlreadyExists => std.debug.print("File `{s}` already exists...\n", .{new_file_str}),
                os.RenameError.NameTooLong => std.debug.print("File name `{s}` is too long\n", .{new_file_str}),
                else => std.debug.print("Something unexpected happened when accessing the file\nReport this for help: {any}\n", .{err}),
            }
            return err;
        };
    }
};

// info can be found at | https://developer.valvesoftware.com/wiki/DEM_(file_format)#Demo_Header
fn createFileName(file_str: []const u8, fmt_str: []const u8) ![]u8 {
    const HEADER_FIELD_OFFSET = [_]i64{ 4, 4, 260, 260, 260, 260, 4, 4, 4, 4 };
    const HEADER_CHAR_MAP = [_]u8{ 'x', 'x', 's', 'p', 'm', 'g', 'T', 't', 'f', 'l' }; // 'x' are not supported for now
    var demo_fp = try fs.openFileAbsolute(file_str, .{ .mode = .read_only });
    defer (demo_fp.close());
    var tstamp: time.epoch.EpochSeconds = undefined;
    tstamp.secs = @as(u64, @intCast(time.timestamp()));

    var ret_str: []u8 = try heap.raw_c_allocator.alloc(u8, 5); // This is going to be slow as fuck but fuck it we ball
    ret_str[0] = 'D';
    ret_str[1] = 'E';
    ret_str[2] = 'M';
    ret_str[3] = 'O';
    ret_str[4] = '-';

    try demo_fp.seekTo(0); // Make sure we're at the start
    try demo_fp.seekBy(8); // Skip the "HL2DEMO\0" field

    for (fmt_str) |ch| {
        var buffer_len: usize = 0;
        const old_strlen: usize = ret_str.len;
        switch (ch) {
            'p', 'm', 's' => blk: {
                const buffer: []u8 = try heap.raw_c_allocator.alloc(u8, @intCast(260));
                defer (heap.raw_c_allocator.free(buffer));
                try demo_fp.seekTo(8);
                for (HEADER_CHAR_MAP, 0..HEADER_CHAR_MAP.len) |c, i| { // Seek appropriate offset
                    if (ch == c) {
                        break;
                    } else try demo_fp.seekBy(HEADER_FIELD_OFFSET[i]);
                }

                _ = try demo_fp.read(buffer); // Read the current bytes into the buffer

                for (buffer) |c| {
                    if (c != 0) {
                        buffer_len += 1;
                    } else break;
                }

                ret_str = try heap.raw_c_allocator.realloc(ret_str, ret_str.len + buffer_len + 1); // Reallocate for the new field - MAY ERROR
                for (0..buffer_len, old_strlen..ret_str.len - 1) |i, j| ret_str[j] = buffer[i];

                break :blk;
            },

            'T', 't', 'f' => blk: {
                const buffer: []u8 = try heap.raw_c_allocator.alloc(u8, @intCast(4));
                defer (heap.raw_c_allocator.free(buffer));

                try demo_fp.seekTo(8);
                for (HEADER_CHAR_MAP, 0..HEADER_CHAR_MAP.len) |c, i| { // Seek appropriate offset
                    if (ch == c) {
                        break;
                    } else try demo_fp.seekBy(HEADER_FIELD_OFFSET[i]);
                }

                _ = try demo_fp.read(buffer); // Read the current bytes into the buffer

                var num_out: i32 = 0;
                for (0..buffer.len) |i| {
                    num_out += (@as(i32, @intCast(@as(u8, @bitCast(buffer[i])))) * (std.math.pow(i32, 16, @as(i32, @intCast(i * 2))))); // Nightmare fuel
                }
                var fmtstr: []u8 = undefined;

                // Handle case 'T' since that is a float and not an int
                if (ch == 'T') {
                    const flt_out: f32 = @as(f32, @bitCast(num_out));
                    fmtstr = try fmt.allocPrint(heap.raw_c_allocator, "{d:.0}", .{flt_out}); // Don't include any dots since that may fuck with things
                } else fmtstr = try fmt.allocPrint(heap.raw_c_allocator, "{}", .{num_out});
                defer (heap.raw_c_allocator.free(fmtstr));

                ret_str = try heap.raw_c_allocator.realloc(ret_str, ret_str.len + fmtstr.len + 1); // Reallocate for the new field - MAY ERROR
                for (0..fmtstr.len, old_strlen..ret_str.len - 1) |i, j| ret_str[j] = fmtstr[i];

                break :blk;
            },
            'H' => blk: {
                const inputstr: []u8 = try heap.raw_c_allocator.alloc(u8, 1064);
                defer (heap.raw_c_allocator.free(inputstr));

                try demo_fp.seekTo(8);
                _ = try demo_fp.read(inputstr);

                const fmtstr = try fmt.allocPrint(heap.raw_c_allocator, "{}", .{hash.Wyhash.hash(123, inputstr)});
                defer (heap.raw_c_allocator.free(fmtstr));

                ret_str = try heap.raw_c_allocator.realloc(ret_str, ret_str.len + fmtstr.len + 1); // Reallocate for the new field - MAY ERROR
                for (0..fmtstr.len, old_strlen..ret_str.len - 1) |i, j| ret_str[j] = fmtstr[i];

                break :blk;
            },
            // TODO: These next two are a fucking mess... see if you can clean them up a bit
            'S' => blk: { // Time stamp - TODO: THIS IS CURRENTLY IN UTC...
                var day: time.epoch.DaySeconds = tstamp.getDaySeconds();
                const fmtstr = try fmt.allocPrint(heap.raw_c_allocator, "H{d:0>2}-M{d:0>2}-S{d:0>2}", .{ day.getHoursIntoDay(), day.getMinutesIntoHour(), day.getSecondsIntoMinute() });
                defer (heap.raw_c_allocator.free(fmtstr));
                ret_str = try heap.raw_c_allocator.realloc(ret_str, ret_str.len + fmtstr.len + 1); // Reallocate for the new field - MAY ERROR
                for (0..fmtstr.len, old_strlen..ret_str.len - 1) |i, j| ret_str[j] = fmtstr[i];

                break :blk;
            },
            'D' => blk: { // Date stamp
                var day: time.epoch.EpochDay = tstamp.getEpochDay();
                var month = day.calculateYearDay().calculateMonthDay().month;
                const year = day.calculateYearDay().year;
                const day_of_month = day.calculateYearDay().calculateMonthDay().day_index;
                const fmtstr = try fmt.allocPrint(heap.raw_c_allocator, "M{d:0>2}-D{d:0>2}-Y{d:0>2}", .{ month.numeric(), day_of_month, year });
                defer (heap.raw_c_allocator.free(fmtstr));

                ret_str = try heap.raw_c_allocator.realloc(ret_str, ret_str.len + fmtstr.len + 1); // Reallocate for the new field - MAY ERROR
                for (0..fmtstr.len, old_strlen..ret_str.len - 1) |i, j| ret_str[j] = fmtstr[i];

                break :blk;
            },
            else => return FmtErr.InvalidFormatArg,
        }
        ret_str[ret_str.len - 1] = '-'; // Add in a separator
    }
    return ret_str;
}
