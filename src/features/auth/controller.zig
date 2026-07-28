const spider = @import("spider");
const guard = @import("../../core/auth/guard.zig");
const password = @import("../../core/auth/password.zig");
const session = @import("../../core/auth/session.zig");

const LoginForm = struct {
    email: []const u8,
    password: []const u8,
};

pub fn loginPage(c: *spider.Ctx) !spider.Response {
    if (session.userId(c) != null) return c.redirect("/home");
    return renderLogin(c, "");
}

pub fn login(c: *spider.Ctx) !spider.Response {
    const form = c.parseForm(LoginForm) catch
        return renderLogin(c, "Enter both your email address and password.");

    const user = (try spider.pg.queryOne(
        guard.User,
        c.arena,
        \\SELECT id, email, display_name, password_hash, role,
        \\       must_change_password, active
        \\FROM app_users WHERE LOWER(email) = LOWER($1)
    ,
        .{form.email},
    )) orelse return renderLogin(c, "The email address or password is incorrect.");

    if (!user.active or !password.verify(c.arena, c._io, user.password_hash, form.password)) {
        return renderLogin(c, "The email address or password is incorrect.");
    }
    return session.issue(c, user.id);
}

pub fn logout(c: *spider.Ctx) !spider.Response {
    return session.clear(c);
}

fn renderLogin(c: *spider.Ctx, error_message: []const u8) !spider.Response {
    return c.view("auth/login", .{
        .error_message = error_message,
        .has_error = error_message.len > 0,
    }, .{
        .headers = &.{.{ "Cache-Control", "no-store" }},
    });
}
