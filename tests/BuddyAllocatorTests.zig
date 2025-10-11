const BuddyAllocator = @import("Kernel").BuddyAllocator;
const KernelTypes = @import("Kernel").KernelTypes;
const std = @import("std");
const testing = std.testing;

// We must test a few things:
// max order block with 1 iteration all allocations of uniform size
// max order block with 10 iterations all allocations of uniform size
// max order block with 1 iteration all allocations of random size
// max order block with 10 iterations all allocations of random size
// random memory map with 1 iteration all allocations of uniform size
// random memory map with 10 iterations all allocations of uniform size
// random memory map with 1 iteration all allocations of random size
// random memory map with 10 iterations all allocations of random size
test "Memory exhaustion" {
    const max_block_size: usize = @as(usize, 0x1) << BuddyAllocator.max_order;
    const pages = testing.allocator_instance.allocator().alloc(KernelTypes.PageFrameMetadata, max_block_size) catch unreachable;
    var allocator = BuddyAllocator.create(pages);

    const allocated_addresses: []*u8 = testing.allocator_instance.allocator().alloc(*u8, 4096) catch |err| {
        std.log.err("Reached error: {s}\n", .{@errorName(err)});
        unreachable;
    };

    for (0..4096) |idx| {
        const page = allocator.allocatePages(1) catch |err| {
            std.log.err("Reached error: {s}\n", .{@errorName(err)});
            unreachable;
        };
        allocated_addresses[idx] = @alignCast(@ptrCast(page.ptr));
    }

    std.log.info("Reached", .{});
    std.debug.print("HELLO", .{});
}
