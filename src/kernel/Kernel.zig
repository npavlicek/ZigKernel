const std = @import("std");
const KernelArgs = @import("KernelArgs.zig");
const Interrupts = @import("Interrupts.zig");
const print = @import("Serial.zig").formatStackPrint;

fn int3_trap() callconv(.{ .x86_64_interrupt = .{} }) void {
    print("Hit the int3 handler!\n", .{});
}

pub fn main(args: KernelArgs) noreturn {
    print("Hello world from the kernel!\n", .{});

    print("Length of args: {}\n", .{args.memory_map.len});

    for (args.memory_map) |cur| {
        print("Type: {s}, Start: 0x{X}, Pages: {}\n", .{ @tagName(cur.type), cur.start, cur.pages });
    }

    var idt = args.idt;

    @memset(idt[1..20], Interrupts.GateDescriptor{
        .gate_type = .TrapGate,
    });

    args.idt[3].gate_type = .TrapGate;
    args.idt[3].offset_low = @truncate(@intFromPtr(&int3_trap));
    args.idt[3].offset_high = @truncate(@intFromPtr(&int3_trap) >> 16);
    args.idt[3].segment_selector = .{
        .index = 1,
    };
    args.idt[3].present = true;
    args.idt[3].dpl = 0;

    @breakpoint();

    print("Num interrupts: {}\n", .{args.idt.len});

    print("offset_high: 0x{X}\n", .{args.idt[3].offset_high});
    print("offset_low: 0x{X}\n", .{args.idt[3].offset_low});

    while (true) {}

    unreachable;
}
