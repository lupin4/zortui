//! Renders a dashboard headlessly and prints it, so the whole stack can be
//! exercised without a TTY: `zig build run-screenshot`.
//!
//! Add `-- --ansi` for the colored form, or `-- --html` for a standalone page.

const std = @import("std");
const zortui = @import("zortui");

const Body = zortui.Body;
const Container = zortui.Container;
const GridBody = zortui.GridBody;
const Grid = zortui.Grid;

const Scene = struct {
    cpu: [120]f64,
    net: [120]f64,

    fn init() Scene {
        var self: Scene = .{ .cpu = undefined, .net = undefined };
        for (0..120) |i| {
            const t: f64 = @floatFromInt(i);
            self.cpu[i] = @sin(t / 9.0) * 35.0 + 55.0;
            self.net[i] = @cos(t / 5.0) * 25.0 + 40.0;
        }
        return self;
    }

    fn view(self: *Scene, ui: *Container) anyerror!void {
        try ui.row(.{ .layout = .{ .size = .{ .cells = 1 } } }, Body.plain(header));
        try ui.grid(.{
            .columns = &.{ .{ .fr = 2 }, .{ .fr = 1 } },
            .rows = &.{ .{ .cells = 11 }, .{ .fr = 1 } },
            .layout = .{ .gap = 1 },
        }, GridBody.with(self, cells));
        try ui.statusBar(.{
            .items = &.{
                .{ .key = "q", .label = "quit" },
                .{ .key = "↑↓", .label = "select" },
            },
            .right = &.{.{ .label = "30fps" }},
        });
    }

    fn header(r: *Container) anyerror!void {
        try r.heading("zortui — zig");
        try r.spacer(.fill);
        try r.badge(.{ .text = "LIVE" });
    }

    fn cells(self: *Scene, g: *Grid) anyerror!void {
        try g.panel(
            .{ .title = "Throughput", .subtitle = "60s" },
            .{},
            Body.with(self, throughput),
        );
        try g.panel(.{ .title = "Cores" }, .{}, Body.with(self, cores));
        try g.panel(.{ .title = "Processes" }, .{ .cols = 2 }, Body.plain(processes));
    }

    fn throughput(self: *Scene, p: *Container) anyerror!void {
        // The series array outlives the frame because it is built in the arena,
        // not on this stack: a child draws after the function declaring it has
        // returned.
        const series = try p.ctx.allocator.alloc(zortui.graphics.Series, 2);
        series[0] = .{ .values = &self.cpu, .label = "cpu" };
        series[1] = .{ .values = &self.net, .label = "net" };
        try p.graph(.{
            .series = series,
            .axis = true,
            .legend = true,
            .plot = .{ .fill = true },
        });
    }

    fn cores(_: *Scene, p: *Container) anyerror!void {
        const items = try p.ctx.allocator.alloc(zortui.widgets.MeterItem, 8);
        for (items, 0..) |*item, i| {
            const n: f64 = @floatFromInt(i);
            item.* = .{ .label = try p.fmt("c{d}", .{i}), .value = 0.15 + n * 0.11 };
        }
        try p.meters(.{ .items = items });
    }

    fn processes(p: *Container) anyerror!void {
        try p.table(.{
            .rows = &.{
                .{ .cells = &.{ "1", "systemd", "0.1", "12M" } },
                .{ .cells = &.{ "412", "hqtui", "12.5", "48M" } },
                .{ .cells = &.{ "1201", "zig", "41.8", "1.2G" } },
            },
            .columns = &.{
                .{ .title = "PID", .alignment = .right },
                .{ .title = "NAME" },
                .{ .title = "CPU%", .alignment = .right },
                .{ .title = "MEM", .alignment = .right },
            },
            .selected = 1,
            .zebra = true,
        }, "");
    }
};

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    // `toSlice` rather than `iterate`: on Windows the command line is one
    // UTF-16 string that has to be split into an allocation, and `iterate` is a
    // compile error there.
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const mode: []const u8 = if (args.len > 1) args[1] else "";

    var scene = Scene.init();
    var screen = try zortui.renderToScreen(allocator, 84, 22, "dark", Body.with(&scene, Scene.view));
    defer screen.deinit();

    const out = if (std.mem.eql(u8, mode, "--ansi"))
        try screen.ansi()
    else if (std.mem.eql(u8, mode, "--html"))
        try zortui.testing.renderToHtml(screen.allocator(), screen, .{})
    else
        try screen.text();

    const stdout = std.Io.File.stdout();
    try stdout.writeStreamingAll(init.io, out);
    try stdout.writeStreamingAll(init.io, "\n");
}
