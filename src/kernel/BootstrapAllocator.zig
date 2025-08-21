const std = @import("std");
const PageFrameMetadata = @import("KernelArgs.zig").PageFrameMetadata;
const MemoryType = @import("KernelArgs.zig").MemoryType;

pages: []align(8) PageFrameMetadata,

pub const Page = [4096]u8;

const Allocator = @This();

pub const Error = error{
    OutOfMemory,
    InvalidMemoryType,
    DoubleFree,
    FreeingRestrictedMemory,
    InvalidNumberOfPages,
};

pub fn create(pages: []align(8) PageFrameMetadata) Allocator {
    return .{
        .pages = pages,
    };
}

pub fn allocatePage(this: *Allocator, memory_type: ?MemoryType) Error!*allowzero align(4096) Page {
    if (memory_type) |memory_type_value| {
        if (memory_type_value == .Reserved or memory_type_value == .Kernel or memory_type_value == .Free)
            return Error.InvalidMemoryType;
    }

    for (this.pages, 0..) |*page, index| {
        if (page.type == MemoryType.Free) {
            if (memory_type) |mem_type| {
                page.type = mem_type;
            } else page.type = .Allocated;
            return @ptrFromInt(index * 4096);
        }
    }

    return Error.OutOfMemory;
}

pub fn freePage(this: *Allocator, page_to_free: *allowzero align(4096) Page) Error!void {
    const page_index = @as(usize, @intFromPtr(page_to_free)) / 4096;

    if (this.pages[page_index].type == .Free)
        return Error.DoubleFree;

    if (this.pages[page_index].type != .Allocated)
        return Error.FreeingRestrictedMemory;

    this.pages[page_index].type = .Free;
}

pub fn allocatePages(this: *Allocator, number_of_pages: usize, memory_type: ?MemoryType) Error![]allowzero align(4096) Page {
    if (number_of_pages < 2)
        return Error.InvalidNumberOfPages;

    if (memory_type) |memory_type_value| {
        if (memory_type_value != .Allocated)
            return Error.InvalidMemoryType;
    }

    var in_range: bool = false;
    var start: usize = 0;
    var number_pages_found: usize = 0;
    const res = try blk: for (this.pages, 0..) |*page, index| {
        if (number_pages_found == number_of_pages) {
            var start_pointer: [*]allowzero align(4096) Page = @ptrFromInt(start);
            break :blk start_pointer[0..number_pages_found];
        }

        if (!in_range and page.type == .Free) {
            in_range = true;
            start = index * 4096;
            number_pages_found = 1;
        } else if (in_range and page.type != .Free) {
            in_range = false;
            number_pages_found = 0;
        } else if (in_range and page.type == .Free) {
            number_pages_found += 1;
        }
    } else {
        break :blk Error.OutOfMemory;
    };

    for (res) |*page| {
        const page_index: usize = @intFromPtr(page) / 4096;
        if (memory_type) |memory_type_value| {
            this.pages[page_index].type = memory_type_value;
        } else {
            this.pages[page_index].type = .Allocated;
        }
    }

    return res;
}

pub fn freePages(this: *Allocator, pages_to_free: []allowzero align(4096) Page) Error!void {
    for (pages_to_free) |*page| {
        try this.freePage(page);
    }
}
