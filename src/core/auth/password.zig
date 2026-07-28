const std = @import("std");

const argon2 = std.crypto.pwhash.argon2;

pub const max_hash_len = 256;

pub fn hash(
    allocator: std.mem.Allocator,
    io: std.Io,
    password: []const u8,
    out: *[max_hash_len]u8,
) ![]const u8 {
    return argon2.strHash(
        password,
        .{
            .allocator = allocator,
            .params = .{
                .t = 3,
                .m = 64 * 1024,
                .p = 1,
            },
        },
        out,
        io,
    );
}

pub fn verify(
    allocator: std.mem.Allocator,
    io: std.Io,
    encoded_hash: []const u8,
    password: []const u8,
) bool {
    argon2.strVerify(
        encoded_hash,
        password,
        .{ .allocator = allocator },
        io,
    ) catch return false;
    return true;
}

test "invalid password does not verify" {
    var out: [max_hash_len]u8 = undefined;
    const encoded = try argon2.strHash(
        "a-correct-password-1",
        .{
            .allocator = std.testing.allocator,
            .params = .{ .t = 1, .m = 32, .p = 1 },
        },
        &out,
        std.testing.io,
    );
    try std.testing.expect(!verify(
        std.testing.allocator,
        std.testing.io,
        encoded,
        "not-the-password",
    ));
}
