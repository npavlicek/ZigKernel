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

    //    var disabled_features = std.Target.Cpu.Feature.Set.empty;
    //    var enabled_features = std.Target.Cpu.Feature.Set.empty;
    //
    //disabled_features.addFeature(@intFromEnum(std.Target.x86.Feature.mmx));
    //disabled_features.addFeature(@intFromEnum(std.Target.x86.Feature.sse));
    //disabled_features.addFeature(@intFromEnum(std.Target.x86.Feature.sse2));
    //disabled_features.addFeature(@intFromEnum(std.Target.x86.Feature.avx));
    //disabled_features.addFeature(@intFromEnum(std.Target.x86.Feature.avx2));
    //enabled_features.addFeature(@intFromEnum(std.Target.x86.Feature.soft_float));

    const kernel = b.addExecutable(.{
        .name = "kernel.elf",
        .root_module = b.createModule(.{
            .optimize = .Debug,
            .root_source_file = b.path("src/Start.zig"),
            .target = b.resolveTargetQuery(.{
                .cpu_arch = .x86_64,
                .os_tag = .freestanding,
                .abi = .none,
                .ofmt = .elf,
                //.cpu_features_add = enabled_features,
                //.cpu_features_sub = disabled_features,
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
