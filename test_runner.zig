const std = @import("std");
const builtin = @import("builtin");

pub fn main(init: std.process.Init) !void {
    var status: u8 = 0;
    const clock: std.Io.Clock = .awake;
    for (builtin.test_functions) |t| {
        std.testing.allocator_instance = .init(std.heap.page_allocator, .{
            .canary = 0xc3a701ba,
            .check_write_after_free = true,
        });
        std.testing.io_instance = .init(std.testing.allocator, .{
            .argv0 = .init(init.minimal.args),
            .environ = init.minimal.environ,
        });
        defer {
            std.testing.io_instance.deinit();
            if (std.testing.allocator_instance.deinit() != 0) status += 1;
        }
        std.testing.environ = init.minimal.environ;

        const start = clock.now(init.io);
        const result = t.func();
        const end = clock.now(init.io);
        const elapsed = start.durationTo(end);
        const name = t.name[5..];
        if (result) |_| {
            std.log.scoped(.PASS).info("{s} ({f})", .{ name, elapsed });
        } else |err| switch (err) {
            error.SkipZigTest => {
                std.log.scoped(.SKIP).info("{s}", .{
                    name,
                });
            },
            else => {
                status += 1;
                std.log.scoped(.FAIL).info("{s} - {t}", .{ name, err });
            },
        }
    }
    std.process.exit(status);
}
