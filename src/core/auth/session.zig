const std = @import("std");
const spider = @import("spider");

pub const cookie_name = "app_session";
const max_age_seconds: i64 = 60 * 60 * 12;

const Claims = struct {
    sub: i64,
    exp: i64,
};

pub fn issue(c: *spider.Ctx, user_id: i64) !spider.Response {
    const now = std.Io.Clock.now(.real, c._io);
    const now_seconds: i64 = @intCast(@divFloor(now.nanoseconds, std.time.ns_per_s));
    const claims = Claims{
        .sub = user_id,
        .exp = now_seconds + max_age_seconds,
    };
    const token = try spider.auth.jwtSign(c.arena, claims, secret());
    const cookie = try c.setCookie(cookie_name, token, .{
        .http_only = true,
        .secure = secureCookies(),
        .same_site = "Lax",
        .path = "/",
        .max_age = @intCast(max_age_seconds),
    });
    const headers = try c.arena.alloc([2][]const u8, 2);
    headers[0] = .{ "Location", "/home" };
    headers[1] = .{ "Cache-Control", "no-store" };
    const cookies = try c.arena.alloc([2][]const u8, 1);
    cookies[0] = .{ cookie_name, cookie };
    return .{
        .status = .see_other,
        .headers = headers,
        .cookies = cookies,
    };
}

pub fn userId(c: *spider.Ctx) ?i64 {
    const token = c.cookie(cookie_name) orelse return null;
    const claims = spider.auth.jwtVerify(
        Claims,
        c.arena,
        c._io,
        token,
        secret(),
    ) catch return null;
    return claims.sub;
}

pub fn clear(c: *spider.Ctx) !spider.Response {
    const cookie = try c.setCookie(cookie_name, "", .{
        .http_only = true,
        .secure = secureCookies(),
        .same_site = "Lax",
        .path = "/",
        .max_age = 0,
    });
    const headers = try c.arena.alloc([2][]const u8, 2);
    headers[0] = .{ "Location", "/login" };
    headers[1] = .{ "Cache-Control", "no-store" };
    const cookies = try c.arena.alloc([2][]const u8, 1);
    cookies[0] = .{ cookie_name, cookie };
    return .{
        .status = .see_other,
        .headers = headers,
        .cookies = cookies,
    };
}

fn secret() []const u8 {
    return spider.env.getOr(
        "SESSION_SECRET",
        "development-only-secret-change-before-production",
    );
}

fn secureCookies() bool {
    return std.mem.eql(
        u8,
        spider.env.getOr("SESSION_SECURE_COOKIE", "false"),
        "true",
    );
}
