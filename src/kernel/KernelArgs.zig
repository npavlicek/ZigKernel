const Interrupts = @import("Interrupts.zig");

idt: []align(8) Interrupts.GateDescriptor = undefined,
pages: []align(8) PageFrameMetadata = undefined,
kernel_code_segment_index: u13 = undefined,


pub const MemoryType = enum(u3) {
    Free,
    Kernel,
    Paging,
    Reserved,
};

pub const PageFrameMetadata = packed struct {
    type: MemoryType = .Reserved,
};
