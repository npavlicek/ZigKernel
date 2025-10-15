const std = @import("std");
const builtin = @import("builtin");
const PageFrameMetadata = @import("KernelTypes.zig").PageFrameMetadata;
const print = @import("Serial.zig").formatStackPrint;

const Allocator = @This();

pub const max_order: usize = 12;

orders: [max_order + 1]?*PageFrameMetadata = undefined,
pages: []PageFrameMetadata = undefined,

pub const Error = error{
    RequestTooLarge,
    OutOfMemory,
    DoubleFree,
    InvalidRequest,
};

inline fn checkPageAlignment(address: usize) void {
    if (comptime builtin.mode == .Debug) {
        if (address % 4096 != 0) {
            std.debug.panic("Address: {} is not page aligned!", .{address});
        }
    }
}

fn addBlock(this: *Allocator, order: u8, address: usize) void {
    checkPageAlignment(address);

    if (this.orders[order]) |current_block_unwrapped| {
        var current_block = current_block_unwrapped;
        while (current_block.next_block) |next_block|
            current_block = next_block;
        current_block.next_block = &this.pages[address / 4096];
    } else this.orders[order] = &this.pages[address / 4096];
}

fn addBlocks(this: *Allocator, start_address: usize, pages: usize) void {
    checkPageAlignment(start_address);

    var current_pages = pages;
    var current_order = std.math.log2_int(usize, pages);
    if (current_order > max_order)
        current_order = max_order;
    var current_address = start_address;
    while (current_pages > 0) {
        const current_order_pages = @as(usize, 1) << current_order;
        var blocks_to_add = current_pages / current_order_pages;
        current_pages %= current_order_pages;
        while (blocks_to_add > 0) {
            this.addBlock(current_order, current_address);
            this.pages[current_address / 4096].type = .Free;
            this.pages[current_address / 4096].order = current_order;
            for (1..current_order_pages) |current_page_index|
                this.pages[current_address / 4096 + current_page_index].type = .Compound;
            current_address += current_order_pages * 4096;
            blocks_to_add -= 1;
        }
        if (current_order > 0)
            current_order -= 1;
    }
}

fn pageFrameAddressToIdx(this: *Allocator, page_frame_metadata_ptr: *PageFrameMetadata) usize {
    return (page_frame_metadata_ptr - this.pages.ptr);
}

fn printOrders(this: *Allocator) void {
    for (0..(max_order + 1)) |idx| {
        if (this.orders[idx]) |order| {
            var current_order = order;
            print("{}: [{}],{*} -> ", .{ idx, this.pageFrameAddressToIdx(current_order), current_order });
            while (current_order.next_block) |next| {
                current_order = next;
                print("[{}]{*} -> ", .{ this.pageFrameAddressToIdx(current_order), current_order });
            }
            print("\n", .{});
        }
    }
}

fn splitBlock(this: *Allocator, order: u8) void {
    // These two cases will be panics because that would indicate invalid kernel logic which is irrecoverable
    if (order > max_order or order < 1)
        std.debug.panicExtra(@returnAddress(), "({s}:{},{}) cannot split order {}, out of range", .{ @src().file, @src().line, @src().column, order });

    const first_block = this.orders[order] orelse {
        std.debug.panicExtra(@returnAddress(), "({s}:{},{}) requested order {} is null", .{ @src().file, @src().line, @src().column, order });
    };

    const order_num_pages = @as(usize, 0x1) << @intCast(order);

    const first_block_index = (first_block - this.pages.ptr);
    const second_block_index = order_num_pages / 2 + first_block_index;

    if (second_block_index > this.pages.len)
        std.debug.panicExtra(@returnAddress(), "({s}:{},{}) second block index {} is out of range", .{ @src().file, @src().line, @src().column, order });

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
    const found_free_order: u8 = blk: for (requested_order..(max_order + 1)) |current_order| {
        if (this.orders[current_order] != null) break :blk @intCast(current_order);
    } else return Error.OutOfMemory;

    var current_order = found_free_order;
    while (current_order != requested_order) : (current_order -= 1) {
        splitBlock(this, current_order);
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

    const size: usize = (@as(usize, 0x1) << @intCast(requested_order)) * 4096;

    return address[0..size];
}

fn removeBlock(this: *Allocator, block: *allowzero PageFrameMetadata) void {
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

fn prependBlock(this: *Allocator, page_idx: usize) void {
    this.pages[page_idx].next_block = this.orders[this.pages[page_idx].order];
    this.orders[this.pages[page_idx].order] = &this.pages[page_idx];
}

fn mergeBuddy(this: *Allocator, address: usize) void {
    checkPageAlignment(address);
    const page_idx: usize = @divExact(address, 4096);

    if (this.pages[page_idx].order >= max_order) return;

    if (this.pages[page_idx].type != .Free)
        std.debug.panic("Trying to merge a non-freed block: 0x{X}\n", .{address});

    const block_size: usize = (@as(usize, @intCast(0x1)) << @intCast(this.pages[page_idx].order)) * 4096;
    const buddy_address = address ^ block_size;
    const buddy_block_idx = @divExact(buddy_address, 4096);

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

        this.prependBlock(page_idx);
        this.mergeBuddy(address);
    } else {
        this.pages[page_idx].type = .Compound;
        this.pages[page_idx].order = undefined;
        this.pages[buddy_block_idx].order += 1;

        this.prependBlock(buddy_block_idx);
        this.mergeBuddy(buddy_address);
    }
}

pub fn freePages(this: *Allocator, pages: *allowzero align(4096) anyopaque) Error!void {
    const page_idx: usize = @divExact(@intFromPtr(pages), 4096);

    // TODO: Maybe if they supply us with a .Compound type we may rewind, and use the beginning of the block type?
    if (this.pages[page_idx].type != .Allocated)
        return Error.InvalidRequest;

    if (this.pages[page_idx].type == .Free)
        return Error.DoubleFree;

    this.pages[page_idx].type = .Free;
    this.prependBlock(page_idx);
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

    addBlocks(&res, current_block_address, current_block_length);

    return res;
}
