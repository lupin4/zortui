//! The handful of kernel32 calls the Windows build makes directly.
//!
//! Zig 0.16 took `GetStdHandle`, `ReadFile`, `WriteFile` and the console mode,
//! code page and screen buffer calls out of `std.os.windows.kernel32`, along
//! with the `std.fs.File` paths that used to reach them. A terminal backend is
//! nothing but those calls, so they are declared here, with the signatures the
//! Windows SDK gives them.
//!
//! Nothing outside a `builtin.os.tag == .windows` branch refers to this file,
//! so a POSIX build never analyses it and never asks its linker for kernel32.
//! It is deliberately not re-exported from `root.zig` for the same reason:
//! `refAllDecls` would otherwise drag every extern into a Linux test build.

const std = @import("std");

pub const HANDLE = *anyopaque;
/// Win32 `BOOL`: nonzero is success.
pub const BOOL = c_int;

// ------------------------------------------------------------------ clock

extern "kernel32" fn QueryPerformanceCounter(lpPerformanceCount: *i64) callconv(.winapi) BOOL;
extern "kernel32" fn QueryPerformanceFrequency(lpFrequency: *i64) callconv(.winapi) BOOL;

/// Monotonic nanoseconds since boot, or 0 if the counter is unavailable (it
/// never is on anything since Windows XP, but 0 is the POSIX path's failure
/// value too).
///
/// Split into whole seconds and remainder before scaling: the counter ticks
/// at 10 MHz on current Windows, so `counter * 1e9` would overflow a u64 after
/// about thirty minutes of uptime.
pub fn monotonicNs() u64 {
    var counter: i64 = 0;
    var frequency: i64 = 0;
    if (QueryPerformanceCounter(&counter) == 0) return 0;
    if (QueryPerformanceFrequency(&frequency) == 0) return 0;
    if (counter <= 0 or frequency <= 0) return 0;
    const c: u64 = @intCast(counter);
    const f: u64 = @intCast(frequency);
    return (c / f) * std.time.ns_per_s + (c % f) * std.time.ns_per_s / f;
}
