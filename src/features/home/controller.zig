const spider = @import("spider");
const guard = @import("../../core/auth/guard.zig");

pub fn landing(c: *spider.Ctx) !spider.Response {
    return c.view("home/landing", .{}, .{});
}

pub fn index(c: *spider.Ctx) !spider.Response {
    const result = try guard.requireUser(c, false);
    const user = switch (result) {
        .response => |response| return response,
        .user => |value| value,
    };
    const data = .{
        .display_name = user.display_name,
        .email = user.email,
        .is_admin = user.isAdmin(),
    };
    return c.view(
        if (c.requestKind() == .fragment)
            "home/content"
        else
            "home/index",
        data,
        .{ .headers = &.{.{ "Cache-Control", "no-store" }} },
    );
}
