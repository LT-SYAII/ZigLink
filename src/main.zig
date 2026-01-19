const std = @import("std");
const net = std.net;
const http = std.http;
const sysinfo = @import("sysinfo.zig");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

const DB_FILE = "database.json";

const LinkData = struct {
    url: []const u8,
    timestamp: i64,
};

const LinkEntry = struct {
    code: []const u8,
    url: []const u8,
    timestamp: i64,
};

var db: std.StringHashMap(LinkData) = undefined;

pub fn main() !void {
    db = std.StringHashMap(LinkData).init(allocator);
    defer db.deinit();

    try loadDB();

    const loopback = try net.Address.parseIp4("0.0.0.0", 8081);
    var server = try loopback.listen(.{ .reuse_address = true });
    defer server.deinit();

    std.debug.print("ZigLink Server Running\n", .{});

    while (true) {
        const connection = try server.accept();
        defer connection.stream.close();

        var buffer: [4096]u8 = undefined;
        const size = try connection.stream.read(&buffer);
        const request_text = buffer[0..size];

        if (isBot(request_text)) {
            const bot_msg = "HTTP/1.1 403 Forbidden\r\nContent-Type: application/json\r\n\r\n{\"error\": \"you can't because you're robot!\"}";
            try connection.stream.writeAll(bot_msg);
            continue;
        }

        var iter = std.mem.tokenizeAny(u8, request_text, " \r\n");
        const method = iter.next() orelse continue;
        const path = iter.next() orelse continue;

        if (std.mem.eql(u8, path, "/auth/verify") and std.mem.eql(u8, method, "POST")) {
            try serveAuthCookie(connection.stream);
            continue;
        }

        const is_protected = std.mem.eql(u8, path, "/info") or std.mem.eql(u8, path, "/api/shorten");
        const has_cookie = std.mem.indexOf(u8, request_text, "zig_guard=passed") != null;

        if (is_protected and !has_cookie) {
            const deny_msg = "HTTP/1.1 403 Forbidden\r\nContent-Type: application/json\r\n\r\n{\"error\": \"you can't because you're robot!\"}";
            try connection.stream.writeAll(deny_msg);
            continue;
        }

        if (std.mem.eql(u8, path, "/") or std.mem.startsWith(u8, path, "/?") or std.mem.startsWith(u8, path, "http")) {
            try serveFile(connection.stream, "src/index.html");
        }
        else if (std.mem.eql(u8, path, "/og-image.png")) {
            try serveImage(connection.stream, "src/og-image.png");
        }
        else if (std.mem.eql(u8, path, "/favicon.png")) {
            try serveImage(connection.stream, "src/favicon.png");
        }
        else if (std.mem.eql(u8, path, "/info")) {
            try serveJsonStats(connection.stream);
        }
        else if (std.mem.eql(u8, path, "/api/shorten") and std.mem.eql(u8, method, "POST")) {
            if (std.mem.indexOf(u8, request_text, "\r\n\r\n")) |body_start| {
                const body = request_text[body_start + 4 ..];
                try handleShorten(connection.stream, body);
            }
        } 
        else {
            if (path.len > 1) {
                const code = path[1..]; 
                if (db.get(code)) |data| {
                    try serveRedirect(connection.stream, data.url);
                } else {
                    try serve404(connection.stream);
                }
            } else {
                try serve404(connection.stream);
            }
        }
    }
}

fn isBot(request: []const u8) bool {
    if (std.mem.indexOf(u8, request, "User-Agent: ")) |idx| {
        const start = idx + 12;
        const end = std.mem.indexOfPos(u8, request, start, "\r\n") orelse request.len;
        const ua = request[start..end];
        if (std.mem.indexOf(u8, ua, "curl") != null) return true;
        if (std.mem.indexOf(u8, ua, "wget") != null) return true;
        if (std.mem.indexOf(u8, ua, "Postman") != null) return true;
        if (std.mem.indexOf(u8, ua, "python") != null) return true;
        if (std.mem.indexOf(u8, ua, "axios") != null) return true;
        if (std.mem.indexOf(u8, ua, "Go-http-client") != null) return true;
        if (std.mem.indexOf(u8, ua, "Java") != null) return true;
    }
    return false;
}

fn serveAuthCookie(stream: net.Stream) !void {
    const header = "HTTP/1.1 200 OK\r\nSet-Cookie: zig_guard=passed; Path=/; HttpOnly; Max-Age=86400\r\nContent-Length: 2\r\n\r\nOK";
    try stream.writeAll(header);
}

fn loadDB() !void {
    const file = std.fs.cwd().openFile(DB_FILE, .{}) catch |err| {
        if (err == error.FileNotFound) return;
        return err;
    };
    defer file.close();
    const stat = try file.stat();
    if (stat.size == 0) return;
    const content = try file.readToEndAlloc(allocator, 10 * 1024 * 1024);
    defer allocator.free(content);
    const parsed = try std.json.parseFromSlice([]LinkEntry, allocator, content, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    for (parsed.value) |item| {
        const key = try allocator.dupe(u8, item.code);
        const val = LinkData{ .url = try allocator.dupe(u8, item.url), .timestamp = item.timestamp };
        try db.put(key, val);
    }
}

fn saveDB() !void {
    const file = try std.fs.cwd().createFile(DB_FILE, .{});
    defer file.close();
    var list = std.ArrayList(LinkEntry).init(allocator);
    defer list.deinit();
    var iter = db.iterator();
    while (iter.next()) |entry| {
        try list.append(LinkEntry{ .code = entry.key_ptr.*, .url = entry.value_ptr.url, .timestamp = entry.value_ptr.timestamp });
    }
    try std.json.stringify(list.items, .{ .whitespace = .indent_2 }, file.writer());
}

fn serveFile(stream: net.Stream, path: []const u8) !void {
    const file = std.fs.cwd().openFile(path, .{}) catch {
        try serve404(stream);
        return;
    };
    defer file.close();
    const content = try file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(content);
    const header = "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nConnection: close\r\n\r\n";
    try stream.writeAll(header);
    try stream.writeAll(content);
}

fn serveImage(stream: net.Stream, path: []const u8) !void {
    const file = std.fs.cwd().openFile(path, .{}) catch {
        try serve404(stream);
        return;
    };
    defer file.close();
    const content = try file.readToEndAlloc(allocator, 5 * 1024 * 1024);
    defer allocator.free(content);
    const header = "HTTP/1.1 200 OK\r\nContent-Type: image/png\r\nConnection: close\r\n\r\n";
    try stream.writeAll(header);
    try stream.writeAll(content);
}

fn serveJsonStats(stream: net.Stream) !void {
    var links_json = std.ArrayList(u8).init(allocator);
    defer links_json.deinit();
    try links_json.appendSlice("[");
    var db_iter = db.iterator();
    var first = true;
    while (db_iter.next()) |entry| {
        if (!first) try links_json.appendSlice(","); 
        first = false;
        const item = try std.fmt.allocPrint(allocator, 
            "{{\"code\":\"{s}\",\"url\":\"{s}\",\"created\":{d}}}", 
            .{entry.key_ptr.*, entry.value_ptr.url, entry.value_ptr.timestamp}
        );
        defer allocator.free(item);
        try links_json.appendSlice(item);
    }
    try links_json.appendSlice("]");
    const count = db.count();
    
    // Info OS Basic
    const info = sysinfo.collect(allocator) catch sysinfo.SystemInfo{
        .distro="Unknown", .kernel="-", .arch="-", .hostname="-", .cpu_model="-",
        .cpu_cores=0, .ram_total_mb=0, .ram_free_mb=0, .uptime_sec=0, .user="-"
    };

    const response_body = try std.fmt.allocPrint(allocator, 
        "{{\"status\":\"online\",\"os\":{{\"distro\":\"{s}\",\"kernel\":\"{s}\",\"arch\":\"{s}\",\"hostname\":\"{s}\",\"cpu\":\"{s}\",\"cores\":{d},\"ram_total_mb\":{d},\"ram_free_mb\":{d},\"uptime_sec\":{d},\"user\":\"{s}\"}},\"total_links\":{d},\"data\":{s}}}", 
        .{info.distro, info.kernel, info.arch, info.hostname, info.cpu_model, info.cpu_cores, info.ram_total_mb, info.ram_free_mb, info.uptime_sec, info.user, count, links_json.items}
    );
    defer allocator.free(response_body);
    const header = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nAccess-Control-Allow-Origin: *\r\nConnection: close\r\n\r\n";
    try stream.writeAll(header);
    try stream.writeAll(response_body);
}

fn getJsonValue(alloc: std.mem.Allocator, json: []const u8, key: []const u8) !?[]const u8 {
    const needle = try std.fmt.allocPrint(alloc, "\"{s}\":\"", .{key});
    defer alloc.free(needle);
    if (std.mem.indexOf(u8, json, needle)) |start_idx| {
        const value_start = start_idx + needle.len;
        if (std.mem.indexOfPos(u8, json, value_start, "\"")) |end_idx| {
            return try alloc.dupe(u8, json[value_start..end_idx]);
        }
    }
    return null;
}

fn slugify(alloc: std.mem.Allocator, input: []const u8) ![]const u8 {
    const res = try alloc.dupe(u8, input);
    for (res) |*c| {
        if (c.* == ' ' or c.* == '/' or c.* == '\\') c.* = '-';
    }
    return res;
}

fn handleShorten(stream: net.Stream, body: []const u8) !void {
    const url = try getJsonValue(allocator, body, "url") orelse {
        try stream.writeAll("HTTP/1.1 400 Bad Request\r\nContent-Type: application/json\r\n\r\n{\"error\":\"Missing URL field\"}");
        return;
    };
    defer allocator.free(url);

    // STRICT URL CHECK
    if (std.mem.indexOf(u8, url, " ") != null or (!std.mem.startsWith(u8, url, "http://") and !std.mem.startsWith(u8, url, "https://"))) {
        try stream.writeAll("HTTP/1.1 403 Forbidden\r\nContent-Type: application/json\r\n\r\n{\"error\":\"Access Denied: Invalid URL format!\"}");
        return;
    }

    const alias_opt = try getJsonValue(allocator, body, "alias");
    var code: []const u8 = undefined;

    if (alias_opt) |alias_raw| {
        if (alias_raw.len > 0) {
            const alias = try slugify(allocator, alias_raw);
            allocator.free(alias_raw); 

            if (db.contains(alias)) {
                allocator.free(alias);
                try stream.writeAll("HTTP/1.1 409 Conflict\r\nContent-Type: application/json\r\n\r\n{\"error\":\"Alias taken\"}");
                return;
            }
            code = alias;
        } else {
            allocator.free(alias_raw);
            code = try generateCode();
        }
    } else {
        code = try generateCode();
    }

    const new_data = LinkData{
        .url = try allocator.dupe(u8, url),
        .timestamp = std.time.timestamp(),
    };
    try db.put(code, new_data);

    saveDB() catch |err| {
        std.debug.print("Error saving DB: {any}\n", .{err});
    };

    const response = try std.fmt.allocPrint(allocator, "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nAccess-Control-Allow-Origin: *\r\n\r\n{{\"short_code\": \"{s}\"}}", .{code});
    defer allocator.free(response);
    try stream.writeAll(response);
}

fn serveRedirect(stream: net.Stream, url: []const u8) !void {
    const response = try std.fmt.allocPrint(allocator, "HTTP/1.1 301 Moved Permanently\r\nLocation: {s}\r\n\r\n", .{url});
    defer allocator.free(response);
    try stream.writeAll(response);
}
fn serve404(stream: net.Stream) !void {
    try stream.writeAll("HTTP/1.1 404 Not Found\r\nContent-Type: application/json\r\n\r\n{\"error\":\"Link not found\"}");
}
fn generateCode() ![]const u8 {
    const charset = "abcdefghijklmnopqrstuvwxyz0123456789";
    var code = try allocator.alloc(u8, 10);
    for (0..10) |i| {
        code[i] = charset[std.crypto.random.intRangeAtMost(usize, 0, charset.len - 1)];
    }
    return code;
}