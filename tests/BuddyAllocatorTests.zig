const BuddyAllocator = @import("Kernel").BuddyAllocator;
const KernelTypes = @import("Kernel").KernelTypes;
const std = @import("std");
const testing = std.testing;

fn getBlockCountPerOrder(allocator: BuddyAllocator) [BuddyAllocator.max_order + 1]usize {
    var block_count: [BuddyAllocator.max_order + 1]usize = [_]usize{0} ** (BuddyAllocator.max_order + 1);
    for (0..BuddyAllocator.max_order + 1) |idx| {
        // count how many blocks
        var count: usize = 0;
        var cur = allocator.orders[idx];
        while (cur) |cur_unwrapped| {
            cur = cur_unwrapped.next_block;
            count += 1;
        }
        block_count[idx] = count;
    }
    return block_count;
}

// We must test a few things:
// 1. max order block with 1 iteration all allocations of uniform size
// 2. max order block with 10 iterations all allocations of uniform size
// 3. max order block with 1 iteration all allocations of random size
// 4. max order block with 10 iterations all allocations of random size
// 5. random memory map with 1 iteration all allocations of uniform size
// 6. random memory map with 10 iterations all allocations of uniform size
// 7. random memory map with 1 iteration all allocations of random size
// 8. random memory map with 10 iterations all allocations of random size
test "Memory exhaustion 1" {
    const max_block_size: usize = @as(usize, 0x1) << BuddyAllocator.max_order;
    const pages = try testing.allocator_instance.allocator().alloc(KernelTypes.PageFrameMetadata, max_block_size);

    @memset(pages, KernelTypes.PageFrameMetadata{
        .type = .Free,
    });

    var allocator = BuddyAllocator.create(pages);
    const allocated_addresses: []*allowzero u8 = try testing.allocator_instance.allocator().alloc(*allowzero u8, max_block_size);

    const initial_blocks = getBlockCountPerOrder(allocator);

    for (0..max_block_size) |idx| {
        const page = try allocator.allocatePages(1);
        allocated_addresses[idx] = @alignCast(@ptrCast(page.ptr));
    }
    for (allocated_addresses) |cur_addr| {
        try allocator.freePages(@alignCast(@ptrCast(cur_addr)));
    }

    const final_blocks = getBlockCountPerOrder(allocator);

    testing.allocator_instance.allocator().free(pages);
    testing.allocator_instance.allocator().free(allocated_addresses);

    for (0..BuddyAllocator.max_order + 1) |idx| {
        try std.testing.expectEqual(initial_blocks[idx], final_blocks[idx]);
    }
}
