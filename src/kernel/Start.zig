const std = @import("std");
const main = @import("Kernel.zig").main;
const KernelTypes = @import("KernelTypes.zig");
const print = @import("Serial.zig").formatStackPrint;

extern const __stack_end: usize;
extern const __stack_start: usize;

var kernel_args: *KernelTypes.KernelArgs = undefined;

pub fn defaultPanic(
    msg: []const u8,
    first_trace_addr: ?usize,
) noreturn {
    @branchHint(.cold);
    print("KERNEL PANIC: {s} at 0x{X}\n", .{ msg, first_trace_addr.? });
    @trap();
}

pub const panic = std.debug.FullPanic(defaultPanic);

export fn _start() linksection(".kernel_start") callconv(.naked) noreturn {
    asm volatile (
        \\ POPQ %[out]
        : [out] "=r" (kernel_args),
    );

    asm volatile (
        \\ MOV %[stack_top], %%rsp
        \\ MOV %[stack_top], %%rbp
        :
        : [stack_top] "r" (&__stack_end),
        : "rsp", "rbp"
    );

    asm volatile (
        \\ CALLQ *%[kernelTrampoline]
        :
        : [kernelTrampoline] "rax" (&kernelTrampoline),
    );
}

export fn kernelTrampoline() callconv(.C) noreturn {
    main(kernel_args.*);
}
