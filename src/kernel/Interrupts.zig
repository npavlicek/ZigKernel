pub const IdtDescriptor = packed struct(u80) {
    size: u16 = 0,
    offset: u64 = 0,
};

pub const GateType = enum(u4) {
    InterruptGate = 0xE,
    TrapGate = 0xF,
    _,
};

pub const SegmentSelector = packed struct(u16) {
    rpl: u2 = 0,
    ti: bool = false,
    index: u13 = 0,
};

pub const GateDescriptor = packed struct(u128) {
    offset_low: u16 = 0,
    segment_selector: SegmentSelector = .{},
    ist: u3 = 0,
    reserved: u5 = 0,
    gate_type: GateType = .InterruptGate,
    zero: u1 = 0,
    dpl: u2 = 0,
    present: bool = true,
    offset_high: u48 = 0,
    reserved2: u32 = 0,
};
