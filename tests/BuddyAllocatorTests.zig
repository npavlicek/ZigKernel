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
            cur = cur_unwrapped.*.next_block;
            count += 1;
        }
        block_count[idx] = count;
    }
    return block_count;
}

// We must test a few things:
// 1. max order block with 10 iterations all allocations of uniform size
// 2. max order block with 10 iterations all allocations of random size
// 3. fragmented map with 10 iterations all allocations of uniform size
// 4. fragmented map with 10 iterations all allocations of random size
test "Memory exhaustion 1" {
    const max_block_size: usize = @as(usize, 0x1) << BuddyAllocator.max_order;
    var pages = try testing.allocator_instance.allocator().alloc(KernelTypes.PageFrameMetadata, max_block_size);

    @memset(pages, KernelTypes.PageFrameMetadata{
        .type = .Free,
    });

    var allocator = BuddyAllocator.create(pages);
    const allocated_addresses: []*allowzero u8 = try testing.allocator_instance.allocator().alloc(*allowzero u8, max_block_size * 3);

    // 1
    for (0..10) |_| {
        const initial_blocks = getBlockCountPerOrder(allocator);
        var count: usize = 0;
        for (0..max_block_size) |idx| {
            const page = try allocator.allocatePages(1);
            allocated_addresses[idx] = @ptrCast(@alignCast(page.ptr));
            count += 1;
        }
        for (0..count) |idx| {
            try allocator.freePages(@ptrCast(@alignCast(allocated_addresses[idx])));
        }
        const final_blocks = getBlockCountPerOrder(allocator);
        for (0..BuddyAllocator.max_order + 1) |idx| {
            try std.testing.expectEqual(initial_blocks[idx], final_blocks[idx]);
        }
    }

    // 2
    for (0..10) |_| {
        const page_count = (std.crypto.random.int(usize) % max_block_size) + 1;
        const initial_blocks = getBlockCountPerOrder(allocator);
        var count: usize = 0;
        while (allocator.allocatePages(page_count)) |address| {
            allocated_addresses[count] = @ptrCast(@alignCast(address));
            count += 1;
        } else |_| {}
        for (0..count) |index| {
            try allocator.freePages(@ptrCast(@alignCast(allocated_addresses[index])));
        }
        const final_blocks = getBlockCountPerOrder(allocator);
        for (0..BuddyAllocator.max_order + 1) |idx| {
            try std.testing.expectEqual(initial_blocks[idx], final_blocks[idx]);
        }
    }

    // Now we fragment the memory map for the next two tests
    testing.allocator_instance.allocator().free(pages);
    pages = try testing.allocator_instance.allocator().alloc(KernelTypes.PageFrameMetadata, max_block_size * 3);
    defer testing.allocator_instance.allocator().free(allocated_addresses);

    @memset(pages, KernelTypes.PageFrameMetadata{ .type = .Free });

    // Just randomly fragmenting the memory map
    for (1025..3334) |index| {
        pages[index].type = .Reserved;
    }
    for (4000..8353) |index| {
        pages[index].type = .Reserved;
    }

    allocator = BuddyAllocator.create(pages);

    // 3
    for (0..10) |_| {
        const initial_blocks = getBlockCountPerOrder(allocator);
        var total_mem: usize = 0;
        for (initial_blocks, 0..) |block, idx| {
            std.log.info("{}: {}", .{ idx, block });
            total_mem += (@as(usize, 2) << @truncate(idx));
        }
        std.log.info("total memory: 0x{X}\n", .{total_mem});
        var alloc_addr_idx: usize = 0;
        while (allocator.allocatePages(1)) |page| {
            allocated_addresses[alloc_addr_idx] = @ptrCast(@alignCast(page.ptr));
            alloc_addr_idx += 1;
        } else |_| {}
        for (0..alloc_addr_idx) |idx| {
            try allocator.freePages(@ptrCast(@alignCast(allocated_addresses[idx])));
        }
        total_mem = 0;
        const final_blocks = getBlockCountPerOrder(allocator);
        for (final_blocks, 0..) |block, idx| {
            std.log.info("{}: {}", .{ idx, block });
            total_mem += (@as(usize, 2) << @truncate(idx));
        }
        std.log.info("total memory: 0x{X}\n", .{total_mem});
        for (0..BuddyAllocator.max_order + 1) |idx| {
            try std.testing.expectEqual(initial_blocks[idx], final_blocks[idx]);
        }
    }

    // 4
    for (0..10) |_| {
        const page_count = (std.crypto.random.int(usize) % max_block_size) + 1;
        const initial_blocks = getBlockCountPerOrder(allocator);
        var count: usize = 0;
        while (allocator.allocatePages(page_count)) |address| {
            allocated_addresses[count] = @ptrCast(@alignCast(address));
            count += 1;
        } else |_| {}
        for (0..count) |index| {
            try allocator.freePages(@ptrCast(@alignCast(allocated_addresses[index])));
        }
        const final_blocks = getBlockCountPerOrder(allocator);
        for (0..BuddyAllocator.max_order + 1) |idx| {
            try std.testing.expectEqual(initial_blocks[idx], final_blocks[idx]);
        }
    }

    testing.allocator_instance.allocator().free(pages);
}
