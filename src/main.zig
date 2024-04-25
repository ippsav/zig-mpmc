const std = @import("std");
const Atomic = std.atomic.Value;
const Channel = @import("channel.zig").Channel;
const TaggedHead = @import("channel.zig").TaggedHead;

const TaskChannel = Channel(Task, 100);

pub fn sendTask(channel: *TaskChannel, v: Task) !void {
    try channel.send(v);
    std.debug.print("id sent {d}\n", .{v.id});
}

pub fn workTask(channel: *TaskChannel) !void {
    var count: usize = 0;
    while (true) {
        if (count == 2) break;
        const v = channel.recv() orelse {
            std.debug.print("empty channel sleeping...\n", .{});
            std.time.sleep(std.time.ns_per_ms * 100);
            count += 1;
            continue;
        };
        std.debug.print("task received {d} working on it...\n", .{v.id});
        std.time.sleep(std.time.ns_per_ms * 500);
    }
}

pub fn workTaskSync(t: Task) void {
    std.debug.print("task received {d} working on it...\n", .{t.id});
    std.time.sleep(std.time.ns_per_ms * 500);
}

const Task = struct {
    id: usize,
    v: i32,
};

fn syncRun(task_arr: []const Task) void {
    const now = std.time.milliTimestamp();

    for (task_arr) |v| {
        workTaskSync(v);
    }

    const elapsed = std.time.milliTimestamp() - now;
    std.debug.print("sync impl elapsed: {d}ms\n", .{elapsed});
}

fn multiThreadedRun(task_arr: []const Task) !void {
    var task_channel: TaskChannel = undefined;
    task_channel.init();

    var handles: [2]std.Thread = undefined;
    for (0..2) |i| {
        handles[i] = try std.Thread.spawn(.{}, workTask, .{&task_channel});
    }

    const now = std.time.milliTimestamp();

    for (task_arr) |v| {
        // _ = try std.Thread.spawn(.{}, sendValue, .{ &int_channel, v });
        // try sendValue(&int_channel, v);
        try sendTask(&task_channel, v);
    }

    handles[0].join();
    const elapsed = std.time.milliTimestamp() - now;
    std.debug.print("elapsed: {d}ms\n", .{elapsed});
}

pub fn main() !void {
    const task_arr = [_]Task{
        .{ .id = 1, .v = 1 },
        .{ .id = 2, .v = 2 },
        .{ .id = 3, .v = 3 },
        .{ .id = 4, .v = 4 },
        .{ .id = 5, .v = 5 },
    };

    syncRun(&task_arr);

    try multiThreadedRun(&task_arr);
}
