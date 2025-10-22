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

    _ = allocator.allocatePages(10) catch unreachable;

    while (true) {}

    unreachable;
}
