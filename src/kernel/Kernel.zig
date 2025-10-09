const std = @import("std");
const KernelTypes = @import("KernelTypes.zig");
const InterruptHandlers = @import("InterruptHandlers.zig");
const BuddyAllocator = @import("BuddyAllocator.zig");
const print = @import("Serial.zig").formatStackPrint;

pub fn main(args: KernelTypes.KernelArgs) noreturn {
    InterruptHandlers.setDefaultInterruptHandlers(args.idt, args.kernel_code_segment_index);

    print("Hello world from the kernel!\n", .{});

    // TODO:
    // 1. Complete buddy allocator
    // 1.5. Test the buddy allocator
    // 2. Remove identity map of physical memory
    // 3. Improve the interrupt handlers and panic handling!

    var allocator = BuddyAllocator.create(args.pages);

    var allocs: [10_000]*allowzero align(4096) u8 = [_]*allowzero align(4096) u8{undefined} ** 10_000;

    var count: usize = 0;
    while (allocator.allocatePages(1024)) |val| {
        allocs[count] = @ptrCast(val.ptr);
        count += 1;
    } else |_| {}

    print("Got {} allocations!", .{count});

    const allocs_to_free = allocs[0..count];

    count = 0;
    for (allocs_to_free) |alloc| {
        allocator.freePages(alloc) catch |err| {
            std.debug.panic("Caught an error: {s}\n", .{@errorName(err)});
        };
        count += 1;
    }

    print("Freed {} allocations!\n", .{count});

    while (true) {}

    unreachable;
}
