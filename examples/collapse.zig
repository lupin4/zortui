//! Collapsed borders in Zig: `zig build run-collapse`.
//!
//! The same scene as examples/collapse.ts in the TypeScript reference and the
//! Rust, Go and Python examples, so the five outputs can be diffed. They are
//! expected to be byte for byte the same, which is what keeps the ports honest.

const std = @import("std");
const zortui = @import("zortui");

const Container = zortui.Container;

fn view(ui: *Container) anyerror!void {
    try ui.row(.{ .layout = .{ .size = .{ .cells = 5 } } }, zortui.Body.plain(top));
    try ui.row(.{ .layout = .{ .size = .{ .cells = 4 } } }, zortui.Body.plain(bottom));
}

fn top(row: *Container) anyerror!void {
    try row.panel(.{ .title = "CPU" }, zortui.Body.plain(cpu));
    try row.panel(.{ .title = "Memory" }, zortui.Body.plain(memory));
    try row.panel(.{ .title = "Disk" }, zortui.Body.plain(disk));
}

fn bottom(row: *Container) anyerror!void {
    try row.panel(.{ .title = "Network" }, zortui.Body.plain(network));
    try row.panel(.{ .title = "Errors" }, zortui.Body.plain(errors));
}

fn cpu(p: *Container) anyerror!void {
    try p.meter(.{ .value = 0.62, .label = "all" });
}

fn memory(p: *Container) anyerror!void {
    try p.meter(.{ .value = 0.31, .label = "used" });
}

fn disk(p: *Container) anyerror!void {
    try p.meter(.{ .value = 0.87, .label = "root" });
}

const rx = [_]f64{ 3, 7, 2, 9, 4, 8, 6 };

fn network(p: *Container) anyerror!void {
    try p.sparkline(.{ .values = &rx, .label = "rx " });
}

fn errors(p: *Container) anyerror!void {
    try p.text("none", .{});
}

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const stdout = std.Io.File.stdout();

    const plain = try zortui.testing.renderToText(allocator, 60, 9, "dark", zortui.Body.plain(view));
    defer allocator.free(plain);
    const merged = try zortui.testing.renderCollapsedToText(allocator, 60, 9, "dark", zortui.Body.plain(view));
    defer allocator.free(merged);

    const out = try std.fmt.allocPrint(
        allocator,
        "--- default ---\n{s}\n--- collapsed ---\n{s}\n",
        .{ plain, merged },
    );
    defer allocator.free(out);
    try stdout.writeStreamingAll(init.io, out);
}
