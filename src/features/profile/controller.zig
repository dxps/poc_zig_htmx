const std = @import("std");
const spider = @import("spider");
const guard = @import("../../core/auth/guard.zig");
const password = @import("../../core/auth/password.zig");
const validation = @import("../../core/validation.zig");

const EmailForm = struct {
    email: []const u8,
    current_password: []const u8,
};

const PasswordForm = struct {
    current_password: []const u8,
    new_password: []const u8,
    confirm_password: []const u8,
};

pub fn index(c: *spider.Ctx) !spider.Response {
    const user = try readyUser(c);
    if (user.response) |response| return response;
    return renderProfile(c, user.user.?, "", "", c.query("updated") != null);
}

pub fn updateEmail(c: *spider.Ctx) !spider.Response {
    const authenticated = try readyUser(c);
    if (authenticated.response) |response| return response;
    const user = authenticated.user.?;
    const form = c.parseForm(EmailForm) catch
        return renderProfile(c, user, "Complete both email fields.", "", false);

    if (!validation.validEmail(form.email)) {
        return renderProfile(c, user, "Enter a valid email address.", "", false);
    }
    if (!password.verify(c.arena, c._io, user.password_hash, form.current_password)) {
        return renderProfile(c, user, "Your current password is incorrect.", "", false);
    }
    const Duplicate = struct { id: i64 };
    if (try spider.pg.queryOne(
        Duplicate,
        c.arena,
        "SELECT id FROM app_users WHERE LOWER(email) = LOWER($1) AND id <> $2",
        .{ form.email, user.id },
    ) != null) {
        return renderProfile(c, user, "That email address is already in use.", "", false);
    }
    try spider.pg.query(
        void,
        c.arena,
        "UPDATE app_users SET email = $1, updated_at = NOW() WHERE id = $2",
        .{ form.email, user.id },
    );
    return c.redirect("/profile?updated=1");
}

pub fn updatePassword(c: *spider.Ctx) !spider.Response {
    const authenticated = try readyUser(c);
    if (authenticated.response) |response| return response;
    const user = authenticated.user.?;
    const form = c.parseForm(PasswordForm) catch
        return renderProfile(c, user, "", "Complete all password fields.", false);

    if (!password.verify(c.arena, c._io, user.password_hash, form.current_password)) {
        return renderProfile(c, user, "", "Your current password is incorrect.", false);
    }
    if (!validation.validPassword(form.new_password)) {
        return renderProfile(
            c,
            user,
            "",
            "Use at least 10 characters, including a letter and a number.",
            false,
        );
    }
    if (!std.mem.eql(u8, form.new_password, form.confirm_password)) {
        return renderProfile(c, user, "", "The new passwords do not match.", false);
    }
    try savePassword(c, user.id, form.new_password);
    return c.redirect("/profile?updated=1");
}

pub fn initialPasswordPage(c: *spider.Ctx) !spider.Response {
    const result = try guard.requireUser(c, true);
    const user = switch (result) {
        .response => |response| return response,
        .user => |value| value,
    };
    if (!user.must_change_password) return c.redirect("/home");
    return renderInitial(c, user, "");
}

pub fn setInitialPassword(c: *spider.Ctx) !spider.Response {
    const result = try guard.requireUser(c, true);
    const user = switch (result) {
        .response => |response| return response,
        .user => |value| value,
    };
    if (!user.must_change_password) return c.redirect("/home");
    const form = c.parseForm(PasswordForm) catch
        return renderInitial(c, user, "Complete all password fields.");

    if (!password.verify(c.arena, c._io, user.password_hash, form.current_password)) {
        return renderInitial(c, user, "The initial password is incorrect.");
    }
    if (!validation.validPassword(form.new_password)) {
        return renderInitial(
            c,
            user,
            "Use at least 10 characters, including a letter and a number.",
        );
    }
    if (!std.mem.eql(u8, form.new_password, form.confirm_password)) {
        return renderInitial(c, user, "The new passwords do not match.");
    }
    if (std.mem.eql(u8, form.current_password, form.new_password)) {
        return renderInitial(c, user, "Choose a password different from the initial one.");
    }
    try savePassword(c, user.id, form.new_password);
    return c.redirect("/home");
}

const Authenticated = struct {
    user: ?guard.User = null,
    response: ?spider.Response = null,
};

fn readyUser(c: *spider.Ctx) !Authenticated {
    const result = try guard.requireUser(c, false);
    return switch (result) {
        .user => |user| .{ .user = user },
        .response => |response| .{ .response = response },
    };
}

fn savePassword(c: *spider.Ctx, user_id: i64, new_password: []const u8) !void {
    var hash_buffer: [password.max_hash_len]u8 = undefined;
    const encoded = try password.hash(c.arena, c._io, new_password, &hash_buffer);
    try spider.pg.query(
        void,
        c.arena,
        \\UPDATE app_users
        \\SET password_hash = $1, must_change_password = $2, updated_at = NOW()
        \\WHERE id = $3
    ,
        .{ encoded, false, user_id },
    );
}

fn renderProfile(
    c: *spider.Ctx,
    user: guard.User,
    email_error: []const u8,
    password_error: []const u8,
    updated: bool,
) !spider.Response {
    const data = .{
        .display_name = user.display_name,
        .email = user.email,
        .is_admin = user.isAdmin(),
        .email_error = email_error,
        .has_email_error = email_error.len > 0,
        .password_error = password_error,
        .has_password_error = password_error.len > 0,
        .updated = updated,
    };
    return c.view(
        if (c.requestKind() == .fragment)
            "profile/content"
        else
            "profile/index",
        data,
        .{ .headers = &.{.{ "Cache-Control", "no-store" }} },
    );
}

fn renderInitial(c: *spider.Ctx, user: guard.User, error_message: []const u8) !spider.Response {
    return c.view("profile/initial_password", .{
        .display_name = user.display_name,
        .email = user.email,
        .error_message = error_message,
        .has_error = error_message.len > 0,
    }, .{ .headers = &.{.{ "Cache-Control", "no-store" }} });
}
