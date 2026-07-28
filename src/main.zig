const std = @import("std");
const spider = @import("spider");

const schema = @import("core/db/schema.zig");
const auth_controller = @import("features/auth/controller.zig");
const home_controller = @import("features/home/controller.zig");
const profile_controller = @import("features/profile/controller.zig");
const users_controller = @import("features/users/controller.zig");

pub const spider_templates = @import("spider_templates").EmbeddedTemplates;

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();

    try spider.pg.init(allocator, init.io, .{});
    defer spider.pg.deinit();
    try schema.migrateAndSeed(allocator, init.io);

    var server = spider.appWithConfig(.{
        .port = 8080,
        .host = "127.0.0.1",
        .views_dir = "./src",
        .layout = "layout",
        .static_dir = "./public",
        .env = .development,
    });
    defer server.deinit();

    _ = server
        .staticDir("./public")
        .onError(onError)
        .get("/", home_controller.landing, .{})
        .get("/login", auth_controller.loginPage, .{})
        .post("/login", auth_controller.login, .{})
        .post("/logout", auth_controller.logout, .{})
        .get("/home", home_controller.index, .{})
        .get("/profile", profile_controller.index, .{})
        .post("/profile/email", profile_controller.updateEmail, .{})
        .post("/profile/password", profile_controller.updatePassword, .{})
        .get("/account/initial-password", profile_controller.initialPasswordPage, .{})
        .post("/account/initial-password", profile_controller.setInitialPassword, .{})
        .get("/admin/users", users_controller.index, .{})
        .post("/admin/users", users_controller.create, .{})
        .get("/admin/users/:id/window", users_controller.window, .{});

    try server.listen(.{});
}

fn onError(c: *spider.Ctx, err: anyerror) !spider.Response {
    std.log.err("request failed: {s}", .{@errorName(err)});
    return c.view("error_page", .{}, .{ .status = .internal_server_error });
}
