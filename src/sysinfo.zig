const std = @import("std");
const builtin = @import("builtin");
pub const SystemInfo = struct {
    distro: []const u8,
    kernel: []const u8,
    arch: []const u8,
    hostname: []const u8,
    cpu_model: []const u8,
    cpu_cores: usize,
    ram_total_mb: u64,
    ram_free_mb: u64,
    uptime_sec: u64,
    user: []const u8,
};
pub fn collect(alloc: std.mem.Allocator) !SystemInfo {
    return SystemInfo{
        .distro = try getFileValue(alloc, "/etc/os-release", "PRETTY_NAME="),
        .kernel = try readOneLine(alloc, "/proc/sys/kernel/osrelease"),
        .arch = @tagName(builtin.cpu.arch),
        .hostname = try readOneLine(alloc, "/etc/hostname"),
        .cpu_model = try getFileValue(alloc, "/proc/cpuinfo", "model name\t: "),
        .cpu_cores = try countCpuCores(alloc),
        .ram_total_mb = try getRamValue(alloc, "MemTotal:"),
        .ram_free_mb = try getRamValue(alloc, "MemAvailable:"),
        .uptime_sec = try getUptime(alloc),
        .user = std.posix.getenv("USER") orelse "unknown",
    };
}
fn readOneLine(alloc: std.mem.Allocator, path: []const u8) ![]const u8 {
    const file = std.fs.cwd().openFile(path, .{}) catch return "unknown";
    defer file.close();
    const buffer = try file.readToEndAlloc(alloc, 256);
    return std.mem.trim(u8, buffer, " \t\n\r");
}
fn getFileValue(alloc: std.mem.Allocator, path: []const u8, prefix: []const u8) ![]const u8 {
    const file = std.fs.cwd().openFile(path, .{}) catch return "unknown";
    defer file.close();
    const content = try file.readToEndAlloc(alloc, 1024 * 64); 
    defer alloc.free(content);
    var iter = std.mem.tokenizeAny(u8, content, "\n");
    while (iter.next()) |line| {
        if (std.mem.startsWith(u8, line, prefix)) {
            const raw = line[prefix.len ..];
            return try alloc.dupe(u8, std.mem.trim(u8, raw, "\"\t "));
        }
    }
    return "unknown";
}
fn countCpuCores(alloc: std.mem.Allocator) !usize {
    const file = std.fs.cwd().openFile("/proc/cpuinfo", .{}) catch return 1;
    defer file.close();
    const content = try file.readToEndAlloc(alloc, 1024 * 64);
    defer alloc.free(content);
    var count: usize = 0;
    var iter = std.mem.tokenizeAny(u8, content, "\n");
    while (iter.next()) |line| {
        if (std.mem.startsWith(u8, line, "processor")) {
            count += 1;
        }
    }
    return if (count == 0) 1 else count;
}
fn getRamValue(alloc: std.mem.Allocator, key: []const u8) !u64 {
    const val_str = try getFileValue(alloc, "/proc/meminfo", key);
    var iter = std.mem.tokenizeAny(u8, val_str, " ");
    const num_str = iter.next() orelse "0";
    const kb = std.fmt.parseInt(u64, num_str, 10) catch 0;
    return kb / 1024; 
}
fn getUptime(alloc: std.mem.Allocator) !u64 {
    const val_str = try readOneLine(alloc, "/proc/uptime");
    var iter = std.mem.tokenizeAny(u8, val_str, " . "); 
    const num_str = iter.next() orelse "0";
    return std.fmt.parseInt(u64, num_str, 10) catch 0;
}
