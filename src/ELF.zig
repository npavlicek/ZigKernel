pub const Header64 = packed struct(u512) {
    ident: Ident = .{},
    type: Type = .Exec,
    machine: Machine = .x86_64,
    version: u32 = 1,
    entry: u64 = 0,
    program_header_off: u64 = 0,
    section_header_off: u64 = 0,
    flags: u32 = 0,
    header_size: u16 = 0,
    program_header_size: u16 = 0,
    program_header_entry_count: u16 = 0,
    section_header_size: u16 = 0,
    section_header_entry_count: u16 = 0,
    section_name_idx: u16 = 0,
};

pub const Ident = packed struct(u128) {
    magic: u32 = 0x7F454C46,
    class: Class = ._64Bit,
    data: Data = .LE,
    version: u8 = 1,
    os_abi: OsAbi = .SystemV,
    abi_version: u8 = 0,
    padding: u56 = 0,
};

pub const Machine = enum(u16) {
    x86_64 = 0x3E,
    _,
};

pub const Type = enum(u16) {
    None = 0x00,
    Rel = 0x01,
    Exec = 0x02,
    Dyn = 0x03,
    Core = 0x04,
    _,
};

pub const Class = enum(u8) {
    _32Bit = 1,
    _64Bit = 2,
    _,
};

pub const Data = enum(u8) {
    LE = 1,
    BE = 2,
    _,
};

pub const OsAbi = enum(u8) {
    SystemV = 0x00,
    HPUX = 0x01,
    NetBSD = 0x02,
    Linux = 0x03,
    GNUHurd = 0x04,
    Solaris = 0x06,
    AIX = 0x07,
    IRIX = 0x08,
    FreeBSD = 0x09,
    Tru64 = 0x0A,
    NovellModesto = 0x0B,
    OpenBSD = 0x0C,
    OpenVMS = 0x0D,
    NonStopKernel = 0x0E,
    AROS = 0x0F,
    FenixOS = 0x10,
    NuxiCloudABI = 0x11,
    StratusTechOpenVOS = 0x12,
    _,
};

pub const ProgramHeader64 = packed struct(u448) {
    type: PType = .Null,
    flags: PFlags = .X,
    offset: u64 = 0,
    virtual_address: u64 = 0,
    physical_address: u64 = 0,
    file_size: u64 = 0,
    memory_size: u64 = 0,
    _align: u64 = 0,
};

pub const PType = enum(u32) {
    Null = 0x00,
    Load = 0x01,
    Dynamic = 0x02,
    Interpreter = 0x03,
    Note = 0x04,
    ShLib = 0x05,
    ProgramHeader = 0x06,
    Tls = 0x07,
    GnuEhFrame = 0x6474e550,
    GnuStack = 0x6474e551,
    GnuRelRo = 0x6474e552,
    _,
};

pub const PFlags = enum(u32) {
    X = 0x1,
    W = 0x2,
    R = 0x4,
    _,
};

pub const SectionHeader64 = packed struct(u512) {
    name: u32 = 0,
    type: SType = .Null,
    flags: SFlags = .Write,
    address: u64 = 0,
    offset: u64 = 0,
    size: u64 = 0,
    link: u32 = 0,
    info: u32 = 0,
    address_align: u64 = 0,
    entry_size: u64 = 0,
};

pub const SFlags = enum(u64) {
    Write = 0x1,
    Alloc = 0x2,
    ExecInstr = 0x4,
    Merge = 0x10,
    Strings = 0x20,
    InfoLink = 0x40,
    LinkOrder = 0x80,
    OsNonConforming = 0x100,
    Group = 0x200,
    Tls = 0x400,
    MaskOs = 0x0FF00000,
    MaskProc = 0xF0000000,
    Ordered = 0x4000000,
    Exclude = 0x8000000,
};

pub const SType = enum(u32) {
    Null = 0x00,
    ProgBits = 0x01,
    SymTab = 0x02,
    StrTab = 0x03,
    Rela = 0x04,
    Hash = 0x05,
    Dynamic = 0x06,
    Note = 0x07,
    NoBits = 0x08,
    Rel = 0x09,
    ShLib = 0x0A,
    DynSym = 0x0B,
    InitArray = 0x0E,
    FiniArray = 0x0F,
    PreInitArray = 0x10,
    Group = 0x11,
    SymTabShNdx = 0x12,
    Num = 0x13,
    _,
};
