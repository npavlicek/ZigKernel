pub inline fn outb(port: u16, byte: u8) void {
    return asm volatile ("OUTB %[byte], %[port]"
        :
        : [port] "{DX}" (port),
          [byte] "{AL}" (byte),
    );
}

pub inline fn inb(port: u16) u8 {
    return asm volatile ("INB %[port], %[byte]"
        : [byte] "={AL}" (-> u8),
        : [port] "{DX}" (port),
    );
}
