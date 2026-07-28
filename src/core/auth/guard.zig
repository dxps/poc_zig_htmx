const std = @import("std");
const spider = @import("spider");
const session = @import("session.zig");

pub const User = struct {
    id: i64,
    email: []const u8,
    display_name: []const u8,
    password_hash: []const u8,
    role: []const u8,
    must_change_password: bool,
    active: bool,

    pub fn isAdmin(self: User) bool {
        return std.mem.eql(u8, self.role, "admin");
    }
};

pub const Result = union(enum) {
    user: User,
    response: spider.Response,
};

pub fn requireUser(c: *spider.Ctx, allow_password_change: bool) !Result {
    const user_id = session.userId(c) orelse
        return .{ .response = try c.redirect("/login") };
    const user = (try spider.pg.queryOne(
        User,
        c.arena,
        \\SELECT id, email, display_name, password_hash, role,
        \\       must_change_password, active
        \\FROM app_users WHERE id = $1
    ,
        .{user_id},
    )) orelse return .{ .response = try session.clear(c) };

    if (!user.active) return .{ .response = try session.clear(c) };
    if (user.must_change_password and !allow_password_change) {
        return .{ .response = try c.redirect("/account/initial-password") };
    }
    return .{ .user = user };
}

pub fn requireAdmin(c: *spider.Ctx) !Result {
    const result = try requireUser(c, false);
    return switch (result) {
        .response => |response| .{ .response = response },
        .user => |user| if (user.isAdmin())
            .{ .user = user }
        else
            .{ .response = try c.redirect("/home") },
    };
}
