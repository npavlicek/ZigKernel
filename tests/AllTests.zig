const std = @import("std");

test {
    std.testing.log_level = .info;
    _ = @import("BuddyAllocatorTests.zig");
}
