const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const spider_dep = b.dependency("spider_local", .{
        .target = target,
        .optimize = optimize,
        .pg = true,
    });
    const spider_mod = spider_dep.module("spider");

    const app_mod = b.addModule("poc_zig_htmx", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "spider", .module = spider_mod },
        },
    });

    const exe = b.addExecutable(.{
        .name = "poc_zig_htmx",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "spider", .module = spider_mod },
                .{ .name = "poc_zig_htmx", .module = app_mod },
            },
        }),
    });
    const generate_templates = b.addRunArtifact(spider_dep.artifact("generate-templates"));
    generate_templates.addArg("src/");
    generate_templates.addArg("src/embedded_templates.zig");
    exe.step.dependOn(&generate_templates.step);
    exe.root_module.addAnonymousImport("spider_templates", .{
        .root_source_file = b.path("src/embedded_templates.zig"),
    });
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    run_cmd.addPassthruArgs();
    const run_step = b.step("run", "Run the web application");
    run_step.dependOn(&run_cmd.step);

    const tests = b.addTest(.{ .root_module = app_mod });
    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run application unit tests");
    test_step.dependOn(&run_tests.step);
}
