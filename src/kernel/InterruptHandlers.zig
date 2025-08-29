const Interrupts = @import("Interrupts.zig");
const print = @import("Serial.zig").formatStackPrint;

const interrupt_signature = fn () callconv(.{ .x86_64_interrupt = .{} }) void;

pub inline fn setDefaultInterruptHandlers(idt: []align(8) Interrupts.GateDescriptor, code_segment_idx: u13) void {
    const default_descriptor = Interrupts.GateDescriptor{
        .gate_type = .TrapGate,
        .segment_selector = .{
            .index = code_segment_idx,
        },
        .present = true,
        .dpl = 0,
    };

    @memset(idt, default_descriptor);

    setInterruptAddress(&idt[0], &divideError);
    setInterruptAddress(&idt[1], &debugException);
    setInterruptAddress(&idt[2], &nonMaskable);
    setInterruptAddress(&idt[3], &breakpoint);
    setInterruptAddress(&idt[4], &overflow);
    setInterruptAddress(&idt[5], &boundRangeExceeded);
    setInterruptAddress(&idt[6], &invalidOpcode);
    setInterruptAddress(&idt[7], &deviceNotAvailable);
    setInterruptAddress(&idt[8], &doubleFault);
    setInterruptAddress(&idt[9], &coprocessorSegmentOverrun);
    setInterruptAddress(&idt[10], &invalidTSS);
    setInterruptAddress(&idt[11], &segmentNotPresent);
    setInterruptAddress(&idt[12], &stackSegmentFault);
    setInterruptAddress(&idt[13], &generalProtection);
    setInterruptAddress(&idt[14], &pageFault);
    // no 15
    setInterruptAddress(&idt[16], &fpuFloatingPointError);
    setInterruptAddress(&idt[17], &alignmentCheck);
    setInterruptAddress(&idt[18], &machineCheck);
    setInterruptAddress(&idt[19], &simdFloatingPointError);
    setInterruptAddress(&idt[20], &virtualizationException);
    setInterruptAddress(&idt[21], &controlProtectionException);
}

inline fn setInterruptAddress(id: *align(8) Interrupts.GateDescriptor, fn_address: *const interrupt_signature) void {
    id.*.offset_low = @truncate(@intFromPtr(fn_address));
    id.*.offset_high = @truncate(@intFromPtr(fn_address) >> 16);
}

fn divideError() callconv(.{ .x86_64_interrupt = .{} }) void {
    print("Hit the int3 handler!\n", .{});
}

fn debugException() callconv(.{ .x86_64_interrupt = .{} }) void {
    print("Hit the int3 handler!\n", .{});
}

fn nonMaskable() callconv(.{ .x86_64_interrupt = .{} }) void {
    print("Hit the int3 handler!\n", .{});
}

fn breakpoint() callconv(.{ .x86_64_interrupt = .{} }) void {
    print("Hit the breakpoint!\n", .{});
}

fn overflow() callconv(.{ .x86_64_interrupt = .{} }) void {
    print("Hit the int3 handler!\n", .{});
}
fn boundRangeExceeded() callconv(.{ .x86_64_interrupt = .{} }) void {
    print("Hit the int3 handler!\n", .{});
}

fn invalidOpcode() callconv(.{ .x86_64_interrupt = .{} }) void {
    print("Hit the int3 handler!\n", .{});
    asm volatile (
        \\ hlt
    );
}

fn deviceNotAvailable() callconv(.{ .x86_64_interrupt = .{} }) void {
    print("Hit the int3 handler!\n", .{});
}

fn doubleFault() callconv(.{ .x86_64_interrupt = .{} }) void {
    print("Hit the int3 handler!\n", .{});
}

fn coprocessorSegmentOverrun() callconv(.{ .x86_64_interrupt = .{} }) void {
    print("Hit the int3 handler!\n", .{});
}

fn invalidTSS() callconv(.{ .x86_64_interrupt = .{} }) void {
    print("Hit the int3 handler!\n", .{});
}

fn segmentNotPresent() callconv(.{ .x86_64_interrupt = .{} }) void {
    print("Hit the int3 handler!\n", .{});
}

fn stackSegmentFault() callconv(.{ .x86_64_interrupt = .{} }) void {
    print("Hit the int3 handler!\n", .{});
}

fn generalProtection() callconv(.{ .x86_64_interrupt = .{} }) void {
    print("Hit the int3 handler!\n", .{});
}

fn pageFault() callconv(.{ .x86_64_interrupt = .{} }) void {
    print("Hit the int3 handler!\n", .{});
}

fn fpuFloatingPointError() callconv(.{ .x86_64_interrupt = .{} }) void {
    print("Hit the int3 handler!\n", .{});
}

fn alignmentCheck() callconv(.{ .x86_64_interrupt = .{} }) void {
    print("Hit the int3 handler!\n", .{});
}

fn machineCheck() callconv(.{ .x86_64_interrupt = .{} }) void {
    print("Hit the int3 handler!\n", .{});
}

fn simdFloatingPointError() callconv(.{ .x86_64_interrupt = .{} }) void {
    print("Hit the int3 handler!\n", .{});
}

fn virtualizationException() callconv(.{ .x86_64_interrupt = .{} }) void {
    print("Hit the int3 handler!\n", .{});
}

fn controlProtectionException() callconv(.{ .x86_64_interrupt = .{} }) void {
    print("Hit the int3 handler!\n", .{});
}
