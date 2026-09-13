//! The smallest real app: `zig build run-hello`. Press q to quit.

const std = @import("std");
const zortui = @import("zortui");

fn view(ui: *zortui.Container) anyerror!void {
    try ui.panel(.{ .title = "Hello" }, zortui.Body.plain(body));
}

fn body(p: *zortui.Container) anyerror!void {
    try p.text("Hello, terminal.", .{});
    try p.label("Press q to quit.");
}

// Zig 0.16 hands the process environment to `main` rather than exposing a
// global, and capability detection needs it — without it every terminal looks
// like a dumb one.
pub fn main(init: std.process.Init) !void {
    var app = try zortui.App.init(init.gpa, .{
        .terminal = .{ .env = .fromEnviron(&init.minimal.environ) },
    });
    defer app.deinit();

    try app.run(zortui.Body.plain(view));
}
