const Interrupts = @import("Interrupts.zig");

pub const MemoryType = enum(u3) {
    Undefined,
    Free,
    Kernel,
    Paging,
    Allocated,
    Reserved,
};

pub const PageFrameMetadata = struct {
    type: MemoryType = .Undefined,
    next_block: ?*PageFrameMetadata = null,
    prev_block: ?*PageFrameMetadata = null,
};

pub const KernelArgs = struct {
    idt: []align(8) Interrupts.GateDescriptor = undefined,
    pages: []PageFrameMetadata = undefined,
    kernel_code_segment_index: u13 = undefined,
};
