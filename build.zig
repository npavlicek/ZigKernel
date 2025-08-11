const std = @import("std");

pub fn build(b: *std.Build) void {
    const exe = b.addExecutable(.{
        .name = "BOOTx64",
        .root_module = b.createModule(.{
            .optimize = .ReleaseFast,
            .root_source_file = b.path("src/Bootloader.zig"),
            .target = b.resolveTargetQuery(.{
                .cpu_arch = .x86_64,
                .os_tag = .uefi,
                .abi = .msvc,
                .ofmt = .coff,
            }),
        }),
    });

    const kernel = b.addExecutable(.{
        .name = "kernel.elf",
        .root_module = b.createModule(.{
            .optimize = .Debug,
            .root_source_file = b.path("src/Kernel.zig"),
            .target = b.resolveTargetQuery(.{
                .cpu_arch = .x86_64,
                .os_tag = .freestanding,
                .abi = .none,
                .ofmt = .elf,
            }),
            .code_model = .kernel,
        }),
    });
    kernel.setLinkerScript(b.path("./config/kernel.ld"));

    //    const objCopy = b.addObjCopy(kernel.getEmittedBin(), .{
    //        .format = .bin,
    //    });
    //    const objCopyStep = b.addInstallFile(objCopy.getOutput(), "bin/kernel");
    //    b.getInstallStep().dependOn(&objCopyStep.step);

    b.installArtifact(kernel);
    b.installArtifact(exe);
}
