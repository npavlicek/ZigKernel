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

fn addressToIdx(this: *Allocator, page_frame_metadata_ptr: *PageFrameMetadata) usize {
    return (page_frame_metadata_ptr - this.pages.ptr);
}

fn printOrders(this: *Allocator) void {
    for (0..(max_order + 1)) |idx| {
        if (this.orders[idx]) |order| {
            var current_order = order;
            print("{}: [{}],{*} -> ", .{ idx, this.addressToIdx(current_order), current_order });
            while (current_order.next_block) |next| {
                current_order = next;
                print("[{}]{*} -> ", .{ this.addressToIdx(current_order), current_order });
            }
            print("\n", .{});
        }
    }
}

fn splitBlock(this: *Allocator, order: usize) void {
    // These two cases will be panics because that would indicate invalid kernel logic which is irrecoverable
    if (order > max_order or order < 1)
        std.debug.panicExtra(@returnAddress(), "({s}:{},{}) cannot split order {}, out of range", .{ @src().file, @src().line, @src().column, order });

    const first_block = this.orders[order] orelse {
        std.debug.panicExtra(@returnAddress(), "({s}:{},{}) requested order {} is null", .{ @src().file, @src().line, @src().column, order });
    };

    const order_num_pages = 0x1 << order;

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

fn findFreeBlockOrSplit(this: *Allocator, requested_order: usize) Error!void {
    const found_free_order = blk: for (requested_order..(max_order + 1)) |current_order| {
        if (this.orders[current_order] != null) break :blk current_order;
    } else return Error.OutOfMemory;

    splitBlock(this, found_free_order);

    print("Found a free block at order: {}\n", .{found_free_order});
}

pub fn allocatePages(this: *Allocator, num_pages: usize) Error![]u8 {
    // First determine the max order we need
    const requested_order = std.math.log2_int_ceil(@TypeOf(num_pages), num_pages);
    if (requested_order > max_order)
        return Error.RequestTooLarge;

    try findFreeBlockOrSplit(this, requested_order);

    return @as([*]u8, @ptrFromInt(0xDEADBEEF))[0..1];
}

pub fn freePages(this: *Allocator, pages: anytype) void {
    _ = pages;
    _ = this;
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

    return res;
}
