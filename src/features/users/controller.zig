const std = @import("std");
const spider = @import("spider");
const guard = @import("../../core/auth/guard.zig");
const password = @import("../../core/auth/password.zig");
const validation = @import("../../core/validation.zig");

const CreateForm = struct {
    display_name: []const u8,
    email: []const u8,
    initial_password: []const u8,
};

const UserListItem = struct {
    id: i64,
    email: []const u8,
    display_name: []const u8,
    role: []const u8,
    must_change_password: bool,
    active: bool,
};

pub fn index(c: *spider.Ctx) !spider.Response {
    const admin = try getAdmin(c);
    if (admin.response) |response| return response;
    return renderIndex(c, admin.user.?, "", c.query("created") != null);
}

pub fn create(c: *spider.Ctx) !spider.Response {
    const authenticated = try getAdmin(c);
    if (authenticated.response) |response| return response;
    const admin = authenticated.user.?;
    const form = c.parseForm(CreateForm) catch
        return renderIndex(c, admin, "Complete all user fields.", false);

    if (std.mem.trim(u8, form.display_name, " \t\r\n").len < 2) {
        return renderIndex(c, admin, "Enter the user's name.", false);
    }
    if (!validation.validEmail(form.email)) {
        return renderIndex(c, admin, "Enter a valid email address.", false);
    }
    if (!validation.validPassword(form.initial_password)) {
        return renderIndex(
            c,
            admin,
            "The initial password needs 10 characters, a letter, and a number.",
            false,
        );
    }
    const Existing = struct { id: i64 };
    if (try spider.pg.queryOne(
        Existing,
        c.arena,
        "SELECT id FROM app_users WHERE LOWER(email) = LOWER($1)",
        .{form.email},
    ) != null) {
        return renderIndex(c, admin, "A user with that email already exists.", false);
    }

    var hash_buffer: [password.max_hash_len]u8 = undefined;
    const encoded = try password.hash(c.arena, c._io, form.initial_password, &hash_buffer);
    try spider.pg.query(
        void,
        c.arena,
        \\INSERT INTO app_users
        \\    (email, display_name, password_hash, role, must_change_password)
        \\VALUES ($1, $2, $3, 'user', TRUE)
    ,
        .{ form.email, form.display_name, encoded },
    );
    return c.redirect("/admin/users?created=1");
}

pub fn window(c: *spider.Ctx) !spider.Response {
    const authenticated = try getAdmin(c);
    if (authenticated.response) |response| return response;
    const id_text = c.params.get("id") orelse return error.InvalidUserId;
    const user_id = std.fmt.parseInt(i64, id_text, 10) catch return error.InvalidUserId;
    const user = (try spider.pg.queryOne(
        UserListItem,
        c.arena,
        \\SELECT id, email, display_name, role, must_change_password, active
        \\FROM app_users WHERE id = $1
    ,
        .{user_id},
    )) orelse return c.html(
        "<p class=\"notice error\">That user no longer exists.</p>",
        .{ .status = .not_found },
    );

    return c.view("users/window", .{
        .id = user.id,
        .email = user.email,
        .display_name = user.display_name,
        .role = user.role,
        .must_change_password = user.must_change_password,
        .active = user.active,
    }, .{});
}

const Authenticated = struct {
    user: ?guard.User = null,
    response: ?spider.Response = null,
};

fn getAdmin(c: *spider.Ctx) !Authenticated {
    const result = try guard.requireAdmin(c);
    return switch (result) {
        .user => |user| .{ .user = user },
        .response => |response| .{ .response = response },
    };
}

fn renderIndex(
    c: *spider.Ctx,
    admin: guard.User,
    error_message: []const u8,
    created: bool,
) !spider.Response {
    const users = try spider.pg.query(
        UserListItem,
        c.arena,
        \\SELECT id, email, display_name, role, must_change_password, active
        \\FROM app_users ORDER BY display_name, email
    ,
        .{},
    );
    const data = .{
        .display_name = admin.display_name,
        .email = admin.email,
        .is_admin = true,
        .users = users,
        .error_message = error_message,
        .has_error = error_message.len > 0,
        .created = created,
    };
    return c.view(
        if (c.requestKind() == .fragment)
            "users/content"
        else
            "users/index",
        data,
        .{ .headers = &.{.{ "Cache-Control", "no-store" }} },
    );
}
