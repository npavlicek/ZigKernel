pub const GdtDescriptor = packed struct(u80) {
    size: u16 = 0,
    offset: u64 = 0,
};

pub const AccessByte = packed struct(u8) {
    accessed: bool = false,
    rw: bool = false,
    dc: bool = false,
    executable: bool = false,
    descriptor_type: bool = false,
    dpl: u2 = 0,
    present: bool = false,
};

pub const Flags = packed struct(u4) {
    reserved: bool = false,
    long_mode: bool = false,
    size: bool = false,
    granularity: bool = false,
};

pub const SegmentDescriptor = packed struct(u64) {
    limit_low: u16 = 0,
    base_low: u24 = 0,
    access_byte: AccessByte = .{},
    limit_high: u4 = 0,
    flags: Flags = .{},
    base_high: u8 = 0,
};
