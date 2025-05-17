const std = @import("std");
const testing = std.testing;
pub fn MPMCQueue(comptime T: type) type {
    return struct {
        const Self = @This();

        buffer: []?T,
        capacity: usize,
        head: usize = 0,
        tail: usize = 0,
        mutex: std.Thread.Mutex,
        not_empty: std.Thread.Condition = .{},
        not_full: std.Thread.Condition = .{},

        pub fn init(allocator: std.mem.Allocator, capacity: usize) !*Self {
            const self = try allocator.create(Self);
            self.* = Self{
                .buffer = try allocator.alloc(?T, capacity),
                .capacity = capacity,
                .mutex = .{},
                .not_empty = .{},
                .not_full = .{},
            };

            for (self.buffer) |*slot| {
                slot.* = null;
            }

            return self;
        }

        pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
            allocator.free(self.buffer);
            allocator.destroy(self);
        }

        pub fn enqueue(self: *Self, item: T) void {
            self.mutex.lock();
            while ((self.tail + 1) % self.capacity == self.head) self.not_full.wait(&self.mutex);
            self.buffer[self.tail] = item;
            self.tail = (self.tail + 1) % self.capacity;
            self.not_empty.signal();
            self.mutex.unlock();
        }

        pub fn dequeue(self: *Self) T {
            self.mutex.lock();
            while (self.head == self.tail) self.not_empty.wait(&self.mutex);
            const item = self.buffer[self.head].?;
            self.buffer[self.head] = null;
            self.head = (self.head + 1) % self.capacity;
            self.not_full.signal();
            self.mutex.unlock();
            return item;
        }
    };
}

test "enqueue" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    var allocator = arena.allocator();
    var ring_buffer = try MPMCQueue(i32).init(&allocator, 10);
    const item: i32 = 10;
    ring_buffer.enqueue(item);
    try testing.expect(ring_buffer.tail == 1 and ring_buffer.buffer[0] == item);
}

test "dequeue" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    var allocator = arena.allocator();
    var ring_buffer = try MPMCQueue(i32).init(&allocator, 10);
    const item: i32 = 10;
    ring_buffer.enqueue(item);
    const result = ring_buffer.dequeue();
    try testing.expect(result == item);
}
