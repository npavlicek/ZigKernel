const Interrupts = @import("Interrupts.zig");

pub const MemoryType = enum(u3) {
    Undefined,
    Free,
    Allocated,
    /// If a page is a compound type it is part of a block, you must iterate backwards to find the first normal memory type which indicates the status of this block
    Compound,
    Kernel,
    Paging,
    Reserved,
};

pub const PageFrameMetadata = struct {
    type: MemoryType = .Undefined,
    next_block: ?*PageFrameMetadata = null,
    order: u8 = undefined,
};

pub const KernelArgs = struct {
    idt: []align(8) Interrupts.GateDescriptor = undefined,
    pages: []PageFrameMetadata = undefined,
    kernel_code_segment_index: u13 = undefined,
};
