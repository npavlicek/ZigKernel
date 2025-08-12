const MemoryMap = @import("MemoryMap.zig");
const fmt = @import("std").fmt;
const Serial = @import("Serial.zig");

pub const KernelArgs = extern struct {
    memory_map: [*]MemoryMap.MemoryRange,
    memory_map_len: usize = 0,
};

pub fn serialStackPrint(comptime fmtString: []const u8, args: anytype) !void {
    var string_buffer: [256]u8 = [_]u8{0} ** 256;
    const str = try fmt.bufPrint(&string_buffer, fmtString, args);
    Serial.print(str);
}
