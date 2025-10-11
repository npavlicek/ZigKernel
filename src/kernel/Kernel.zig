const std = @import("std");
const KernelTypes = @import("KernelTypes.zig");
const InterruptHandlers = @import("InterruptHandlers.zig");
const BuddyAllocator = @import("BuddyAllocator.zig");
const print = @import("Serial.zig").formatStackPrint;

var allocator: BuddyAllocator = undefined;

fn testAllocator() void {
    var allocs: [500_000]*allowzero align(4096) u8 = [_]*allowzero align(4096) u8{undefined} ** 500_000;

    var random_value: usize = 0;

    asm (
        \\ RDRAND %[rd_vl]
        : [rd_vl] "=r" (random_value),
    );
    random_value %= 4096;
    random_value += 1;

    var count: usize = 0;
    while (allocator.allocatePages(random_value)) |val| {
        allocs[count] = @ptrCast(val.ptr);
        asm (
            \\ RDRAND %[rd_vl]
            : [rd_vl] "=r" (random_value),
        );
        random_value %= 4096;
        random_value += 1;
        count += 1;
    } else |err| {
        switch (err) {
            BuddyAllocator.Error.OutOfMemory => {},
            else => {
                std.debug.panic("Allocation test error: {s} with value: {}\n", .{ @errorName(err), random_value });
            },
        }
    }

    //print("Got {} allocations!\n", .{count});

    const allocs_to_free = allocs[0..count];

    count = 0;
    for (allocs_to_free) |alloc| {
        allocator.freePages(alloc) catch |err| {
            std.debug.panic("Caught an error: {s}\n", .{@errorName(err)});
        };
        count += 1;
    }

    //print("Freed {} allocations!\n", .{count});
}

fn printStatusOfFreeLists() void {
    var total_mem: usize = 0;
    print("Free List Status:\n", .{});
    for (0..BuddyAllocator.max_order + 1) |idx| {
        // count how many blocks
        var count: usize = 0;
        var cur = allocator.orders[idx];
        while (cur) |cur_unwrapped| {
            cur = cur_unwrapped.next_block;
            count += 1;
        }
        print("Order {} has {} blocks\n", .{ idx, count });
        total_mem += count * (@as(usize, 0x1) << @intCast(idx)) * 4096;
    }
    print("Total memory: {}\n", .{total_mem});
}

pub fn main(args: KernelTypes.KernelArgs) noreturn {
    InterruptHandlers.setDefaultInterruptHandlers(args.idt, args.kernel_code_segment_index);

    print("Hello world from the kernel!\n", .{});

    // TODO:
    // 1. Complete buddy allocator
    // 1.5. Test the buddy allocator
    // 2. Remove identity map of physical memory
    // 3. Improve the interrupt handlers and panic handling!

    allocator = BuddyAllocator.create(args.pages);

    printStatusOfFreeLists();

    for (0..5) |_| {
        testAllocator();
        printStatusOfFreeLists();
    }

    print("Reached end of test\n", .{});

    while (true) {}

    unreachable;
}
