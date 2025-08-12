const MemoryMap = @import("MemoryMap.zig");
const fmt = @import("std").fmt;
const Serial = @import("Serial.zig");

pub const KernelArgs = extern struct {
    memory_map: [*]MemoryMap.MemoryRange,
    memory_map_len: usize = 0,
};

pub fn bufPrint(comptime fmtString: []const u8, args: anytype) void {
    var string_buffer: [200]u8 = [_]u8{0} ** 200;
    const str = fmt.bufPrint(&string_buffer, fmtString, args) catch unreachable;
    Serial.print(str);
}
