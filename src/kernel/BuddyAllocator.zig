const std = @import("std");
const builtin = @import("builtin");
const PageFrameMetadata = @import("KernelTypes.zig").PageFrameMetadata;
const print = @import("Serial.zig").formatStackPrint;

// PERF: Go through each function and optimize make sure each variable is only calculated once and loops arent too crazy
// TODO: Clean up our functions and make sure they are more readable
// TODO: Create unit tests for all public facing functions
// TODO: Make public facing functions cover all edge cases and return errors
// FIXME: Fix the create() function in order to make it calculate our blocks correctly, currently it will generate blocks on non buddy boundaries
// A method for this would just go from max order to min order and iterate by current block size (cur_addr += cur_block_size) and
// check it fits within our address space and that the whole contiguous space is free if it is create a block out of it. As a consequence we can simplify
// our addBlocks() function as we make it only take

const Allocator = @This();

pub const max_order: usize = 12;
pub const order_sizes_pages: [max_order + 1]usize = block: {
    var res: [max_order + 1]usize = undefined;
    for (&res, 0..) |*cur, idx|
        cur.* = @as(usize, 0x1) << @truncate(idx);
    break :block res;
};
pub const order_sizes_bytes: [max_order + 1]usize = block: {
    var res: [max_order + 1]usize = undefined;
    for (order_sizes_pages, 0..) |val, idx| {
        res[idx] = val * 4096;
    }
    break :block res;
};

orders: [max_order + 1]?*PageFrameMetadata = undefined,
pages: []PageFrameMetadata = undefined,

pub const Error = error{
    RequestTooLarge,
    OutOfMemory,
    DoubleFree,
    InvalidRequest,
};

fn addBlock(this: *Allocator, order: u8, address: usize) void {
    std.debug.assert(order < max_order + 1);
    std.debug.assert(address % 4096 == 0);

    if (this.orders[order]) |current_block_unwrapped| {
        var current_block = current_block_unwrapped;
        while (current_block.next_block) |next_block|
            current_block = next_block;
        current_block.next_block = &this.pages[address / 4096];
    } else this.orders[order] = &this.pages[address / 4096];
}

fn addBlocks(this: *Allocator, start_address: usize, pages: usize) void {
    std.debug.assert(start_address % 4096 == 0);
    std.debug.assert(pages > 0);

    var current_pages = pages;
    var current_order = std.math.log2_int(usize, pages);
    if (current_order > max_order)
        current_order = max_order;
    var current_address = start_address;
    while (current_pages > 0) {
        var blocks_to_add = current_pages / order_sizes_pages[current_order];
        current_pages %= order_sizes_pages[current_order];
        while (blocks_to_add > 0) {
            this.addBlock(current_order, current_address);
            this.pages[current_address / 4096].type = .Free;
            this.pages[current_address / 4096].order = current_order;
            for (1..order_sizes_pages[current_order]) |current_page_index|
                this.pages[current_address / 4096 + current_page_index].type = .Compound;
            current_address += order_sizes_bytes[current_order];
            blocks_to_add -= 1;
        }
        if (current_order > 0)
            current_order -= 1;
    }
}

fn pageFrameAddressToIdx(this: *Allocator, page_frame_metadata_ptr: *PageFrameMetadata) usize {
    return (page_frame_metadata_ptr - this.pages.ptr);
}

fn splitBlock(this: *Allocator, order: u8) void {
    std.debug.assert(order < max_order + 1);
    std.debug.assert(order > 0);
    std.debug.assert(this.orders[order] != null);

    const first_block = this.orders[order].?;

    const first_block_index = (first_block - this.pages.ptr);
    const second_block_index = order_sizes_pages[order] / 2 + first_block_index;

    const second_block = &this.pages[second_block_index];

    // Remove the first block from the original order
    this.orders[order] = first_block.next_block;

    // Prepare block one and two
    first_block.next_block = second_block;
    first_block.type = .Free;
    first_block.order = order - 1;

    second_block.next_block = this.orders[order - 1];
    second_block.type = .Free;
    second_block.order = order - 1;

    // Insert these two blocks into order - 1
    this.orders[order - 1] = first_block;
}

fn findFreeBlockOrSplit(this: *Allocator, requested_order: u8) Error!void {
    std.debug.assert(requested_order < max_order + 1);

    const found_free_order: u8 = blk: for (requested_order..(max_order + 1)) |current_order| {
        if (this.orders[current_order] != null) break :blk @intCast(current_order);
    } else return Error.OutOfMemory;

    var current_order = found_free_order;
    while (current_order != requested_order) : (current_order -= 1) {
        splitBlock(this, current_order);
    }
}

fn removeBlock(this: *Allocator, block: *PageFrameMetadata) void {
    std.debug.assert(@intFromPtr(block) >= @intFromPtr(this.pages.ptr));
    std.debug.assert(@intFromPtr(block) < @intFromPtr(this.pages.ptr + this.pages.len));

    std.debug.assert(block.order < max_order + 1);
    std.debug.assert(block.next_block != block);

    var cur_block_opt = this.orders[block.order];
    var prev_block_opt: ?*PageFrameMetadata = null;

    var count: usize = 0;
    while (cur_block_opt) |cur_block| {
        if (count > 10_000)
            @panic("Took too long to find block");

        if (cur_block == block) {
            if (prev_block_opt) |prev_block| {
                prev_block.next_block = cur_block.next_block;
            } else {
                this.orders[block.order] = cur_block.next_block;
            }
            block.next_block = null;
            return;
        }

        prev_block_opt = cur_block;
        cur_block_opt = cur_block.next_block;
        count += 1;
    }

    @panic("Block does not exist at supplied order");
}

fn prependBlockToFreeList(this: *Allocator, page_idx: usize) void {
    std.debug.assert(this.pages[page_idx].type == .Free);

    this.pages[page_idx].next_block = this.orders[this.pages[page_idx].order];
    this.orders[this.pages[page_idx].order] = &this.pages[page_idx];
}

fn mergeBuddy(this: *Allocator, address: usize) void {
    std.debug.assert(address % 4096 == 0);

    const page_idx: usize = @divExact(address, 4096);
    std.debug.assert(this.pages[page_idx].type == .Free);

    if (this.pages[page_idx].order >= max_order) return;

    const block_size: usize = order_sizes_bytes[this.pages[page_idx].order];
    const buddy_address = address ^ block_size;
    const buddy_block_idx = @divExact(buddy_address, 4096);

    // Since our function is recursive if the buddy is not free we just mark the end of recursion and return
    if (this.pages[buddy_block_idx].type != .Free)
        return;

    // Two unequal order blocks cannot be merged
    if (this.pages[page_idx].order != this.pages[buddy_block_idx].order)
        return;

    // Remove these blocks from the orders arrays
    this.removeBlock(&this.pages[page_idx]);
    this.removeBlock(&this.pages[buddy_block_idx]);

    // Handle kernel page metadata second
    if (page_idx < buddy_block_idx) {
        this.pages[buddy_block_idx].type = .Compound;
        this.pages[buddy_block_idx].order = undefined;
        this.pages[page_idx].order += 1;

        this.prependBlockToFreeList(page_idx);
        this.mergeBuddy(address);
    } else {
        this.pages[page_idx].type = .Compound;
        this.pages[page_idx].order = undefined;
        this.pages[buddy_block_idx].order += 1;

        this.prependBlockToFreeList(buddy_block_idx);
        this.mergeBuddy(buddy_address);
    }
}

pub fn allocatePages(this: *Allocator, num_pages: usize) Error![]allowzero align(4096) u8 {
    if (num_pages == 0) return Error.InvalidRequest;

    // First determine the max order we need
    const requested_order = std.math.log2_int_ceil(@TypeOf(num_pages), num_pages);
    if (requested_order > max_order)
        return Error.RequestTooLarge;

    // Verify we have a free block or split a higher order to get desired order block
    try findFreeBlockOrSplit(this, requested_order);

    const address: [*]allowzero align(4096) u8 = @ptrFromInt(this.pageFrameAddressToIdx(this.orders[requested_order].?) * 4096);
    this.orders[requested_order].?.type = .Allocated;
    this.orders[requested_order] = this.orders[requested_order].?.next_block;

    const size: usize = order_sizes_bytes[requested_order];

    return address[0..size];
}

pub fn freePages(this: *Allocator, pages: *allowzero align(4096) anyopaque) Error!void {
    const page_idx: usize = @divExact(@intFromPtr(pages), 4096);

    // TODO: Maybe if they supply us with a .Compound type we may rewind, and use the beginning of the block type?
    if (this.pages[page_idx].type != .Allocated)
        return Error.InvalidRequest;

    if (this.pages[page_idx].type == .Free)
        return Error.DoubleFree;

    this.pages[page_idx].type = .Free;
    this.prependBlockToFreeList(page_idx);
    this.mergeBuddy(@intFromPtr(pages));
}

pub fn create(pages: []PageFrameMetadata) Allocator {
    // To begin our process of creating a buddy allocator we must now scan our memory to find the highest order we can
    var res: Allocator = .{
        .pages = pages,
        .orders = [_]?*PageFrameMetadata{null} ** (max_order + 1),
    };

    var current_block_length: usize = 0;
    var current_block_address: usize = 0;
    for (pages, 0..) |page, index| {
        if (page.type == .Free) {
            if (current_block_length == 0)
                current_block_address = index * 4096;
            current_block_length += 1;
        } else if (current_block_length > 0) {
            addBlocks(&res, current_block_address, current_block_length);
            current_block_length = 0;
        }
    }

    if (current_block_length > 0) {
        addBlocks(&res, current_block_address, current_block_length);
    }

    return res;
}

test create {
    var debug_allocator = std.heap.DebugAllocator(.{}).init;
    var allocator = debug_allocator.allocator();

    std.testing.log_level = .info;

    for (order_sizes_pages, 0..) |size, order| {
        std.log.info("{}: {}", .{ order, size });
    }

    const mem = try allocator.alloc(u8, order_sizes_pages[max_order]);

    allocator.free(mem);

    _ = debug_allocator.deinit();
}
