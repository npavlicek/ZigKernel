pub inline fn outb(port: u16, byte: u8) void {
    return asm volatile ("outb %[byte], %[port]"
        :
        : [port] "{dx}" (port),
          [byte] "{al}" (byte),
    );
}

pub inline fn inb(port: u16) u8 {
    return asm volatile ("inb %[port], %[byte]"
        : [byte] "={al}" (-> u8),
        : [port] "{dx}" (port),
    );
}
