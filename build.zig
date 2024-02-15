const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "demodaemon",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    const arglib = b.addStaticLibrary(.{
        .name = "args",
        .root_source_file = .{ .path = "src/args.zig" },
        .target = target,
        .optimize = optimize,
    });

    exe.linkLibC();
    b.installArtifact(arglib);
    b.installArtifact(exe);
    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
