pub const Pml4 = packed struct(u64) {
    present: bool = false,
    rw: bool = false,
    us: bool = false,
    write_through: bool = false,
    cache_disable: bool = false,
    accessed: bool = false,
    _ignored: u5 = 0,
    hlat: bool = false,
    physical_address: u40 = 0,
    _ignored2: u11 = 0,
    execute_disable: bool = false,
};

pub const Pdpte = packed struct(u64) {
    present: bool = false,
    rw: bool = false,
    us: bool = false,
    write_through: bool = false,
    cache_disable: bool = false,
    accessed: bool = false,
    _ignored: u5 = 0,
    hlat: bool = false,
    physical_address: u40 = 0,
    _ignored2: u11 = 0,
    execute_disable: bool = false,
};

pub const Pde = packed struct(u64) {
    present: bool = false,
    rw: bool = false,
    us: bool = false,
    write_through: bool = false,
    cache_disable: bool = false,
    accessed: bool = false,
    _ignored: u5 = 0,
    hlat: bool = false,
    physical_address: u40 = 0,
    _ignored2: u11 = 0,
    execute_disable: bool = false,
};

pub const PageEntry = packed struct(u64) {
    present: bool = false,
    rw: bool = false,
    us: bool = false,
    write_through: bool = false,
    cache_disable: bool = false,
    accessed: bool = false,
    dirty: bool = false,
    pat: bool = false,
    global: bool = false,
    _ignored: u2 = 0,
    hlat: bool = false,
    physical_address: u40 = 0,
    _ignored2: u11 = 0,
    execute_disable: bool = false,
};
