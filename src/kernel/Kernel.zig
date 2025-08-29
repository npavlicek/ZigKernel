const std = @import("std");
const KernelTypes = @import("KernelTypes.zig");
const InterruptHandlers = @import("InterruptHandlers.zig");
const BuddyAllocator = @import("BuddyAllocator.zig");
const print = @import("Serial.zig").formatStackPrint;

pub fn main(args: KernelTypes.KernelArgs) noreturn {
    InterruptHandlers.setDefaultInterruptHandlers(args.idt, args.kernel_code_segment_index);

    print("Hello world from the kernel!\n", .{});

    var allocator2 = BuddyAllocator.create(args.pages);
    _ = &allocator2;

    while (true) {}

    unreachable;
}
