const std = @import("std");

pub const min_password_len = 10;

pub fn validEmail(email: []const u8) bool {
    if (email.len < 5 or email.len > 254) return false;
    const at = std.mem.indexOfScalar(u8, email, '@') orelse return false;
    if (at == 0 or at + 3 > email.len) return false;
    return std.mem.indexOfScalar(u8, email[at + 1 ..], '.') != null;
}

pub fn validPassword(password: []const u8) bool {
    if (password.len < min_password_len or password.len > 128) return false;
    var has_letter = false;
    var has_number = false;
    for (password) |char| {
        has_letter = has_letter or std.ascii.isAlphabetic(char);
        has_number = has_number or std.ascii.isDigit(char);
    }
    return has_letter and has_number;
}

test "email validation" {
    try std.testing.expect(validEmail("alex@example.com"));
    try std.testing.expect(!validEmail("not-an-email"));
    try std.testing.expect(!validEmail("@example.com"));
}

test "password validation" {
    try std.testing.expect(validPassword("correct-horse-7"));
    try std.testing.expect(!validPassword("short7"));
    try std.testing.expect(!validPassword("onlyletterslong"));
}
