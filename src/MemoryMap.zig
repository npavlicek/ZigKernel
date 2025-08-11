pub const MemoryType = enum(u3) {
    Free,
    Kernel,
    MemoryMap,
    Paging,
    Reserved,
};

pub const MemoryRange = packed struct {
    start: usize = 0,
    pages: u64 = 0,
    type: MemoryType = .Free,
};
