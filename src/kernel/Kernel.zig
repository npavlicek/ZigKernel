const std = @import("std");
const KernelArgs = @import("KernelArgs.zig");
const InterruptHandlers = @import("InterruptHandlers.zig");
const print = @import("Serial.zig").formatStackPrint;

pub fn main(args: KernelArgs) noreturn {
    InterruptHandlers.setDefaultInterruptHandlers(args.idt, args.kernel_code_segment_index);

    print("Hello world from the kernel!\n", .{});

    while (true) {}

    unreachable;
}
