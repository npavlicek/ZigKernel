const std = @import("std");
const Serial = @import("Serial.zig");
const KernelArgs = @import("Common.zig").KernelArgs;
const print= @import("Common.zig").serialStackPrint;

pub fn main(args: KernelArgs) noreturn {
    Serial.print("Hello world from the kernel!\n");

    print("Length of args: {}\n", .{args.memory_map_len}) catch unreachable;

    const mem_map = args.memory_map[0..args.memory_map_len];
    for (mem_map) |cur| {
        print("Type: {s}, Start: 0x{X}, Pages: {}\n", .{@tagName(cur.type), cur.start, cur.pages}) catch unreachable;
    }

    while (true) {}
}
