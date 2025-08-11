const std = @import("std");

const Serial = @import("Serial.zig");

export fn _start() linksection(".kernel_start") callconv(.naked) noreturn {
    asm volatile (
        \\ JMPQ *%[kernel_main]
        :
        : [kernel_main] "${rax}" (kernel_main),
    );
}

export fn kernel_main() void {
    Serial.print("Hello world from the kernel!\n");
}
