const std = @import("std");
const builtin = @import("builtin");
const PageFrameMetadata = @import("KernelTypes.zig").PageFrameMetadata;
const print = @import("Serial.zig").formatStackPrint;

const Allocator = @This();

pub const max_order: usize = 12;

orders: [max_order + 1]?*PageFrameMetadata = undefined,
pages: []PageFrameMetadata = undefined,

inline fn checkPageAlignment(address: usize) void {
    if (comptime builtin.mode == .Debug) {
        if (address % 4096 != 0) {
            std.debug.panic("Address: {} is not page aligned!", .{address});
        }
    }
}

fn addBlock(this: *Allocator, order: usize, address: usize) void {
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
            current_address += current_order_pages * 4096;
            blocks_to_add -= 1;
        }
        if (current_order > 0)
            current_order -= 1;
    }
}

fn addressToIdx(this: Allocator, page_frame_metadata_ptr: *PageFrameMetadata) usize {
    return (page_frame_metadata_ptr - this.pages.ptr);
}

fn printOrders(this: Allocator) void {
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

    printOrders(res);

    return res;
}
