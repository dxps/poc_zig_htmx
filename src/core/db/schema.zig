const std = @import("std");
const spider = @import("spider");
const password = @import("../auth/password.zig");

const migrations =
    \\CREATE TABLE IF NOT EXISTS app_users (
    \\    id BIGSERIAL PRIMARY KEY,
    \\    email TEXT NOT NULL,
    \\    display_name TEXT NOT NULL,
    \\    password_hash TEXT NOT NULL,
    \\    role TEXT NOT NULL DEFAULT 'user' CHECK (role IN ('admin', 'user')),
    \\    must_change_password BOOLEAN NOT NULL DEFAULT TRUE,
    \\    active BOOLEAN NOT NULL DEFAULT TRUE,
    \\    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    \\    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    \\);
    \\CREATE UNIQUE INDEX IF NOT EXISTS app_users_email_lower_idx
    \\    ON app_users (LOWER(email));
;

pub fn migrateAndSeed(allocator: std.mem.Allocator, io: std.Io) !void {
    try spider.pg.queryExecute(void, allocator, migrations);

    const admin_email = spider.env.getOr("ADMIN_EMAIL", "admin@example.com");
    const Existing = struct { id: i64 };
    const existing = try spider.pg.queryOne(
        Existing,
        allocator,
        "SELECT id FROM app_users WHERE LOWER(email) = LOWER($1)",
        .{admin_email},
    );
    if (existing != null) return;

    const admin_password = spider.env.getOr("ADMIN_PASSWORD", "ChangeMe123!");
    var hash_buffer: [password.max_hash_len]u8 = undefined;
    const password_hash = try password.hash(allocator, io, admin_password, &hash_buffer);
    try spider.pg.query(
        void,
        allocator,
        \\INSERT INTO app_users
        \\    (email, display_name, password_hash, role, must_change_password)
        \\VALUES ($1, $2, $3, 'admin', FALSE)
    ,
        .{ admin_email, "Administrator", password_hash },
    );
    std.log.warn(
        "Created the default administrator {s}; change ADMIN_PASSWORD outside development",
        .{admin_email},
    );
}
