const std = @import("std");
const Serial = @import("Serial.zig");
const KernelArgs = @import("Common.zig").KernelArgs;
const bufPrint = @import("Common.zig").bufPrint;

pub fn main(args: KernelArgs) noreturn {
    Serial.print("Hello world from the kernel!\n");

    bufPrint("Length of args: {}\n", .{args.memory_map_len});

    const mem_map = args.memory_map[0..args.memory_map_len];
    for (mem_map) |cur| {
        bufPrint("Type: {s}\n", .{@tagName(cur.type)});
    }

    while (true) {}
}
