const IO = @import("IO.zig");

const outb = IO.outb;
const inb = IO.inb;

pub const COM1: u16 = 0x3F8;

pub const SerialError = error{InitFail};

pub fn init() SerialError!void {
    outb(COM1 + 1, 0x00);
    outb(COM1 + 3, 0x80);
    outb(COM1 + 0, 0x03);
    outb(COM1 + 1, 0x00);
    outb(COM1 + 3, 0x03);
    outb(COM1 + 2, 0xC7);
    outb(COM1 + 4, 0x03);
    outb(COM1 + 4, 0x12);

    outb(COM1 + 0, 0xAE);

    if (inb(COM1 + 0) != 0xAE) {
        return error.InitFail;
    }

    outb(COM1 + 4, 0x03);
}

pub fn print(string: []const u8) void {
    for (string) |c| {
        outb(COM1 + 0, c);
    }
}
