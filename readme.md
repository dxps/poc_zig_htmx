# Northstar Admin

A server-rendered administration application built with Zig 0.17, Spider,
PostgreSQL, and HTMX 4.

## Included flows

- A seeded administrator with implicit access to every administrative action.
- Administrator-only user registration with an initial password.
- Mandatory password replacement before a new user can access the application.
- Signed, HttpOnly session cookies.
- Argon2id password hashing.
- User-managed email and password updates.
- Multi-page HTMX navigation and draggable, modeless entity windows.

## Run locally

1. Copy `.env.example` to `.env` and change `SESSION_SECRET`.
2. Start PostgreSQL with `docker compose up -d`.
3. Run `zig build run`.
4. Open `http://127.0.0.1:8080`.

The development administrator defaults to `admin@example.com` with password
`ChangeMe123!`. Set `ADMIN_EMAIL` and `ADMIN_PASSWORD` before the first run to
override these values. Existing administrator credentials are never overwritten.

## Commands

- `zig build test` — application unit tests.
- `zig build` — compile the application.
- `zig build run` — compile and run on port 8080.
