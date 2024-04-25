const std = @import("std");
const Atomic = std.atomic.Value;

fn Node(comptime T: type) type {
    return struct {
        value: T,
        next: ?*Node(T),
    };
}

pub const TaggedHead = packed struct {
    index: usize = 0,
    tag: usize = 0,
};

pub fn Channel(comptime T: type, comptime capacity: usize) type {
    return struct {
        const Self = @This();

        head: Atomic(u128),
        tail: Atomic(usize),
        buffer: [capacity]T = undefined,

        pub fn init(self: *Self) void {
            const head: u128 = @bitCast(TaggedHead{});
            self.head = Atomic(u128).init(head);
            self.tail = Atomic(usize).init(0);
        }

        pub fn send(self: *Self, value: T) !void {
            var old_tail = self.tail.load(.monotonic);
            var new_tail: usize = undefined;
            while (true) {
                new_tail = (old_tail + 1) % capacity;
                const head: TaggedHead = @bitCast(self.head.load(.monotonic));
                if (new_tail == head.index) {
                    return error.ChannelFull;
                }
                old_tail = self.tail.cmpxchgWeak(old_tail, new_tail, .release, .monotonic) orelse break;
            }
            self.buffer[old_tail] = value;
            self.tail.store(new_tail, .release);
        }

        pub fn recv(self: *Self) ?T {
            var old_tagged_head: TaggedHead = @bitCast(self.head.load(.acquire));
            while (true) {
                if (old_tagged_head.index == self.tail.load(.monotonic)) {
                    return null;
                }
                const new_head = TaggedHead{
                    .index = (old_tagged_head.index + 1) % capacity,
                    .tag = old_tagged_head.tag + 1,
                };
                if (self.head.cmpxchgWeak(@bitCast(old_tagged_head), @bitCast(new_head), .acquire, .monotonic)) |v| {
                    old_tagged_head = @bitCast(v);
                } else {
                    const value = self.buffer[old_tagged_head.index];
                    return value;
                }
            }
        }
    };
}

const testing = std.testing;
test "Node basic usage" {
    const IntNode = Node(i32);

    const allocator = testing.allocator;

    const parent_node = try allocator.create(IntNode);
    parent_node.* = .{ .value = 32, .next = null };
    const child_node = try allocator.create(IntNode);
    child_node.* = .{ .value = 42, .next = null };

    defer {
        allocator.destroy(parent_node);
        allocator.destroy(child_node);
    }

    try testing.expectEqual(parent_node.value, 32);
    try testing.expectEqual(parent_node.next, null);

    try testing.expectEqual(child_node.value, 42);
    try testing.expectEqual(child_node.next, null);

    parent_node.*.next = child_node;
    try testing.expectEqual(parent_node.next, child_node);
}

test "Channel basic usage" {
    // const allocator = testing.allocator;
    const IntChannel = Channel(i32, 64);
    std.debug.print("hello", .{});
    var int_channel: IntChannel = undefined;
    int_channel.init();
    // defer int_channel.deinit();

    try int_channel.send(32);
    const val = int_channel.recv();
    try testing.expectEqual(32, val);
}
