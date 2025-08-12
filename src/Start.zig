const main = @import("Kernel.zig").main;
const KernelArgs = @import("Common.zig").KernelArgs;

extern const stack_end: usize;
extern const stack_start: usize;

var kernel_args: *KernelArgs = undefined;

export fn _start() linksection(".kernel_start") callconv(.naked) noreturn {
    asm volatile (
        \\ POPQ %[out]
        : [out] "=r" (kernel_args),
    );

    asm volatile (
        \\ MOV %[stack_top], %%rsp
        \\ MOV %[stack_top], %%rbp
        :
        : [stack_top] "r" (&stack_end),
        : "rsp", "rbp"
    );

    asm volatile (
        \\ CALLQ *%[kernelTrampoline]
        :
        : [kernelTrampoline] "rax" (kernelTrampoline),
    );
}

export fn kernelTrampoline() callconv(.C) noreturn {
    main(kernel_args.*);
}
