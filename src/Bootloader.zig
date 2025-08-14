const std = @import("std");
const uefi = @import("std").os.uefi;
const fmt = @import("std").fmt;

// TODO: maybe replace this with the zig std elf file
const ELF = @import("kernel/ELF.zig");

const Interrupts = @import("kernel/Interrupts.zig");
const Segments = @import("kernel/Segments.zig");
const Serial = @import("kernel/Serial.zig");
const Paging = @import("kernel/Paging.zig");
const KernelArgs = @import("kernel/KernelArgs.zig");

const W = @import("std").unicode.utf8ToUtf16LeStringLiteral;
const print = @import("kernel/Serial.zig").formatStackPrint;

var memory_map: [*]align(8) uefi.tables.MemoryDescriptor = undefined;
var memory_map_size: usize = 0;
var memory_map_key: usize = undefined;
var memory_map_descriptor_size: usize = undefined;
var descriptor_version: u32 = undefined;

var page_table: ?[*]align(4096) Paging.Pdpte = null;

var ranges: ?[]align(8) KernelArgs.MemoryRange = null;

var final_memory_address: usize = 0;

const EfiKernelMemory: uefi.tables.MemoryType = @enumFromInt(0x80000001);
const EfiPagingMemory: uefi.tables.MemoryType = @enumFromInt(0x80000002);
const EfiMemoryMap: uefi.tables.MemoryType = @enumFromInt(0x80000003);

var kernel_args: KernelArgs = undefined;

fn getMemoryMap() void {
    if (memory_map_size == 0) {
        memory_map_size = 1 * @sizeOf(uefi.tables.MemoryDescriptor);
        uefi.system_table.boot_services.?.allocatePool(.loader_data, memory_map_size, &memory_map).err() catch unreachable;
    }
    while (uefi.system_table.boot_services.?.getMemoryMap(
        &memory_map_size,
        memory_map,
        &memory_map_key,
        &memory_map_descriptor_size,
        &descriptor_version,
    ).err() == uefi.Status.Error.BufferTooSmall) {
        uefi.system_table.boot_services.?.freePool(@alignCast(@ptrCast(memory_map))).err() catch unreachable;
        uefi.system_table.boot_services.?.allocatePool(.loader_data, memory_map_size, @ptrCast(&memory_map)).err() catch unreachable;
    }
}

fn loadFile(comptime filePath: []const u8) []align(std.heap.pageSize()) u8 {
    var file_system: ?*uefi.protocol.SimpleFileSystem = undefined;
    uefi.system_table.boot_services.?.locateProtocol(&uefi.protocol.SimpleFileSystem.guid, null, @ptrCast(&file_system)).err() catch {
        Serial.print("Could not locate simple file protocol\n");
    };

    var root: *const uefi.protocol.File = undefined;
    file_system.?.openVolume(&root).err() catch {
        Serial.print("Could not open file volume\n");
    };

    var file: *const uefi.protocol.File = undefined;
    root.open(&file, W(filePath), uefi.protocol.File.efi_file_mode_read, 0).err() catch {
        Serial.print("Could not open file\n");
    };

    var file_info: uefi.FileInfo = undefined;
    var file_info_size: usize = @sizeOf(uefi.FileInfo);
    while (file.getInfo(
        &uefi.FileInfo.guid,
        &file_info_size,
        @ptrCast(&file_info),
    ) == uefi.Status.buffer_too_small) {}

    const file_size_in_pages = std.math.divCeil(usize, file_info.file_size, 4096) catch unreachable;

    var file_buffer_size: usize = file_info.file_size;
    var file_buffer: [*]align(std.heap.pageSize()) u8 = undefined;
    uefi.system_table.boot_services.?.allocatePages(.allocate_any_pages, .loader_data, file_size_in_pages, &file_buffer).err() catch unreachable;

    file.read(&file_buffer_size, file_buffer).err() catch |err| {
        Serial.print("encountered error: ");
        Serial.print(@errorName(err));
        Serial.print("\n");
    };

    return file_buffer[0..(file_size_in_pages * std.heap.pageSize())];
}

fn getOrCreatePage(t: type, p: *anyopaque) ![*]align(4096) t {
    var res: [*]align(4096) t = undefined;
    switch (t) {
        Paging.Pml4, Paging.Pdpte, Paging.Pde, Paging.PageEntry => {
            const page_entry: *Paging.PageEntry = @alignCast(@ptrCast(p));
            if (page_entry.*.present) {
                res = @ptrFromInt(@as(u52, page_entry.physical_address) << 12);
            } else {
                uefi.system_table.boot_services.?.allocatePages(.allocate_any_pages, EfiPagingMemory, 1, @alignCast(@ptrCast(&res))).err() catch unreachable;
                @memset(res[0..512], @bitCast(@as(u64, 0)));
                page_entry.* = @bitCast(@as(u64, 0));
                page_entry.*.present = true;
                page_entry.*.rw = true;
                page_entry.*.us = false;
                page_entry.*.physical_address = @intCast((@intFromPtr(res) >> 12) & 0xFFFFFFFFFF);
            }
        },
        else => {
            return error.InvalidType;
        },
    }
    return res;
}

fn mapMemory(virtual_address: usize, physical_address: usize) !void {
    if (page_table == null) {
        uefi.system_table.boot_services.?.allocatePages(.allocate_any_pages, EfiPagingMemory, 1, @alignCast(@ptrCast(&page_table))).err() catch unreachable;
        @memset(page_table.?[0..512], @bitCast(@as(u64, 0)));
    }

    const pml4_idx: usize = (virtual_address >> 39) & 0x1FF;
    const pdpte_idx: usize = (virtual_address >> 30) & 0x1FF;
    const pde_idx: usize = (virtual_address >> 21) & 0x1FF;
    const pe_idx: usize = (virtual_address >> 12) & 0x1FF;

    const pdpte_table = try getOrCreatePage(Paging.Pdpte, &page_table.?[pml4_idx]);
    const pde_table = try getOrCreatePage(Paging.Pde, &pdpte_table[pdpte_idx]);
    const pte_table = try getOrCreatePage(Paging.PageEntry, &pde_table[pde_idx]);
    const pe = &pte_table[pe_idx];

    if (pe.*.present) {
        return error.AlreadyMapped;
    } else {
        pe.*.physical_address = @truncate(physical_address >> 12);
        pe.*.present = true;
        pe.*.rw = true;
        pe.*.us = false;
    }
}

fn parseMemoryMap() void {
    if (ranges == null) {
        const ranges_len = memory_map_size / memory_map_descriptor_size;
        var ranges_ptr: [*]KernelArgs.MemoryRange = undefined;
        uefi.system_table.boot_services.?.allocatePool(
            EfiMemoryMap,
            ranges_len,
            @ptrCast(&ranges_ptr),
        ).err() catch unreachable;
        ranges = ranges_ptr[0..ranges_len];
    }

    var current_address: usize = @intFromPtr(memory_map);
    const final_address = current_address + memory_map_size;
    var current_index: usize = 0;
    var start_block = true;
    while (current_address < final_address) : (current_address += memory_map_descriptor_size) {
        const current_memory_descriptor = @as(*uefi.tables.MemoryDescriptor, @ptrFromInt(current_address)).*;

        if (current_memory_descriptor.physical_start + (current_memory_descriptor.number_of_pages * 4096) > final_memory_address)
            final_memory_address = current_memory_descriptor.physical_start + (current_memory_descriptor.number_of_pages * 4096);

        const memType: KernelArgs.MemoryType = switch (current_memory_descriptor.type) {
            .conventional_memory, .boot_services_code, .boot_services_data, .persistent_memory, .loader_data, .loader_code => .Free,
            EfiKernelMemory => .Kernel,
            EfiMemoryMap => .MemoryMap,
            EfiPagingMemory => .Paging,
            else => .Reserved,
        };

        if (start_block) {
            ranges.?[current_index].pages = current_memory_descriptor.number_of_pages;
            ranges.?[current_index].start = current_memory_descriptor.physical_start;
            ranges.?[current_index].type = memType;
            current_index += 1;
            start_block = false;
            continue;
        }

        if (ranges.?[current_index - 1].start + (ranges.?[current_index - 1].pages * 4096) == current_memory_descriptor.physical_start and ranges.?[current_index - 1].type == memType) {
            ranges.?[current_index - 1].pages += current_memory_descriptor.number_of_pages;
        } else {
            ranges.?[current_index].pages = current_memory_descriptor.number_of_pages;
            ranges.?[current_index].start = current_memory_descriptor.physical_start;
            ranges.?[current_index].type = memType;
            current_index += 1;
        }
    }

    ranges.?.len = current_index;
}

pub fn main() noreturn {
    const bs = uefi.system_table.boot_services.?;
    const out = uefi.system_table.con_out.?;

    _ = out.clearScreen();

    Serial.init() catch {
        _ = out.outputString(W("Failed to initialize Serial IO"));
    };

    // Load up our kernel
    const kernel_bin = loadFile("\\kernel.elf");

    getMemoryMap();
    parseMemoryMap();

    // Identity map all the physical memory
    var cur_page: usize = 0;
    while (cur_page < final_memory_address) : (cur_page += 4096) {
        mapMemory(cur_page, cur_page) catch unreachable;
    }

    // Map our kernel
    const elf_hdr: *ELF.Header64 = @alignCast(@ptrCast(kernel_bin.ptr));
    for (0..elf_hdr.program_header_entry_count) |i| {
        const cur_entry: *ELF.ProgramHeader64 = @alignCast(@ptrCast(kernel_bin.ptr + elf_hdr.program_header_off + (i * elf_hdr.program_header_size)));
        if (cur_entry.type == .Load) {
            var start: usize = cur_entry.*.virtual_address;
            start &= ~@as(usize, 0xFFF);

            var end: usize = cur_entry.*.virtual_address + cur_entry.*.memory_size;
            if (end & 0xFFF != 0)
                end += 0x1000;
            end &= ~@as(usize, 0xFFF);

            // TODO: maybe update this to allocate a range of pages to be more efficient and also check for overlap
            var current_page: usize = start;
            while (current_page < end) : (current_page += 4096) {
                var current_page_ptr: *anyopaque = undefined;
                uefi.system_table.boot_services.?.allocatePages(.allocate_any_pages, EfiKernelMemory, 1, @ptrCast(@alignCast(&current_page_ptr))).err() catch unreachable;

                mapMemory(current_page, @intFromPtr(current_page_ptr)) catch {
                    uefi.system_table.boot_services.?.freePages(@ptrCast(@alignCast(current_page_ptr)), 1).err() catch unreachable;
                };
            }
        }
    }

    // Set up our interrupt table
    var idtr: *align(8) Interrupts.IdtDescriptor = undefined;
    var idt: [*]align(8) Interrupts.GateDescriptor = undefined;
    const num_interrupts: u64 = 256;

    bs.allocatePool(EfiKernelMemory, @sizeOf(Interrupts.IdtDescriptor), @ptrCast(&idtr)).err() catch unreachable;
    bs.allocatePool(EfiKernelMemory, @sizeOf(Interrupts.GateDescriptor) * num_interrupts, @ptrCast(&idt)).err() catch unreachable;

    // Set up our global descriptor table
    var gdtr: *align(8) Segments.GdtDescriptor = undefined;
    var gdt: [*]align(8) Segments.SegmentDescriptor = undefined;

    bs.allocatePool(EfiKernelMemory, @sizeOf(Segments.GdtDescriptor), @ptrCast(&gdtr)).err() catch unreachable;
    bs.allocatePool(EfiKernelMemory, @sizeOf(Segments.SegmentDescriptor) * 4, @ptrCast(&gdt)).err() catch unreachable;

    getMemoryMap();
    parseMemoryMap();

    uefi.system_table.boot_services.?.exitBootServices(uefi.handle, memory_map_key).err() catch {
        Serial.print("Failed to exit boot services!\n");
    };

    @memset(idt[0..num_interrupts], .{});

    idtr.offset = @intFromPtr(idt);
    idtr.size = (@sizeOf(Interrupts.GateDescriptor) * num_interrupts) - 1;

    print("IDTR: 0x{X} 0x{X} {*} {*}\n", .{ idtr.size, idtr.offset, idtr, idt });

    @memset(gdt[0..1], .{});

    // Now set our segment descriptors
    @memset(gdt[1..4], Segments.SegmentDescriptor{
        .flags = .{
            .long_mode = true,
        },
        .access_byte = .{
            .present = true,
            .rw = true,
            .descriptor_type = true,
            .dc = false,
        },
    });

    // Kernel Code
    gdt[1].access_byte.executable = true;

    // Kernel Data
    gdt[2].access_byte.executable = false;

    // Kernel Stack
    gdt[3].access_byte.executable = false;
    gdt[3].access_byte.dc = true;

    gdtr.size = (@sizeOf(Segments.SegmentDescriptor) * 4) - 1;
    gdtr.offset = @intFromPtr(gdt);

    print("GDTR: 0x{X} 0x{X} {*} {*}\n", .{ gdtr.size, gdtr.offset, gdtr, gdt });

    // Load our page table and jump to our code segment
    asm volatile (
        \\ mov %[pml4], %cr3
        \\ cli
        \\ lgdt (%[gdtr])
        \\ push $0x08
        \\ lea .reload_CS(%rip), %rax
        \\ push %rax
        \\ lretq
        \\ .reload_CS:
        \\ mov $0x10, %ax
        \\ mov %ax, %ds
        \\ mov $0x18, %ax
        \\ mov %ax, %ss
        \\ mov $0x00, %ax
        \\ mov %ax, %es
        \\ mov %ax, %gs
        \\ mov %ax, %fs
        \\ lidt (%[idtr])
        :
        : [pml4] "r" (page_table.?),
          [gdtr] "r" (gdtr),
          [idtr] "r" (idtr),
    );

    // Load the kernel into memory since its memory mapped
    for (0..elf_hdr.program_header_entry_count) |i| {
        const cur_entry: *ELF.ProgramHeader64 = @alignCast(@ptrCast(kernel_bin.ptr + elf_hdr.program_header_off + (i * elf_hdr.program_header_size)));

        if (cur_entry.type == .Load) {
            var file_index: usize = 0;
            while (file_index < cur_entry.file_size) : (file_index += 1) {
                const virtual_ptr: *u8 = @ptrFromInt(cur_entry.virtual_address + file_index);
                const file_ptr: *u8 = @ptrCast(kernel_bin.ptr + cur_entry.offset + file_index);

                virtual_ptr.* = file_ptr.*;
            }

            // Clear out any bss data
            while (file_index < cur_entry.memory_size) : (file_index += 1) {
                const virtual_ptr: *u8 = @ptrFromInt(cur_entry.virtual_address + file_index);
                virtual_ptr.* = 0;
            }
        }
    }

    // Guaranteed to live until the Kernel cleans up the bootloader data/code
    kernel_args = .{
        .memory_map = ranges.?,
        .idt = idt[0..num_interrupts],
    };

    asm volatile (
        \\ PUSHQ %[args]
        \\ JMP *%[kernel_start]
        :
        : [kernel_start] "r" (0xFFFFFFFF80000000),
          [args] "r" (&kernel_args),
    );

    unreachable;
}
