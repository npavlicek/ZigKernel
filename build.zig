const std = @import("std");

pub fn build(b: *std.Build) void {
    var disabled_features = std.Target.Cpu.Feature.Set.empty;
    var enabled_features = std.Target.Cpu.Feature.Set.empty;

    _ = &disabled_features;
    _ = &enabled_features;

    //disabled_features.addFeature(@intFromEnum(std.Target.x86.Feature.mmx));
    //disabled_features.addFeature(@intFromEnum(std.Target.x86.Feature.sse));
    //disabled_features.addFeature(@intFromEnum(std.Target.x86.Feature.sse2));
    //disabled_features.addFeature(@intFromEnum(std.Target.x86.Feature.avx));
    //disabled_features.addFeature(@intFromEnum(std.Target.x86.Feature.avx2));
    //enabled_features.addFeature(@intFromEnum(std.Target.x86.Feature.soft_float));

    const exe = b.addExecutable(.{
        .name = "BOOTx64",
        .root_module = b.createModule(.{
            .optimize = .Debug,
            .root_source_file = b.path("src/Bootloader.zig"),
            .target = b.resolveTargetQuery(.{
                .cpu_arch = .x86_64,
                .os_tag = .uefi,
                .abi = .msvc,
                .ofmt = .coff,
                .cpu_features_add = enabled_features,
                .cpu_features_sub = disabled_features,
            }),
            .strip = false,
            .dwarf_format = .@"64",
        }),
        .use_llvm = true,
        .use_lld = true,
    });

    const kernel_target = b.resolveTargetQuery(.{
        .cpu_arch = .x86_64,
        .os_tag = .freestanding,
        .abi = .none,
        .ofmt = .elf,
        .cpu_features_add = enabled_features,
        .cpu_features_sub = disabled_features,
    });

    const kernel = b.addExecutable(.{
        .name = "kernel.elf",
        .root_module = b.createModule(.{
            .optimize = .Debug,
            .root_source_file = b.path("src/kernel/Start.zig"),
            .target = kernel_target,
            .code_model = .kernel,
            .dwarf_format = .@"64",
            .strip = false,
        }),
        .use_llvm = true,
        .use_lld = true,
    });
    kernel.setLinkerScript(b.path("./config/kernel.ld"));

    const kernel_module = b.createModule(.{
        .root_source_file = b.path("src/kernel/root.zig"),
        .target = b.resolveTargetQuery(.{ .cpu_arch = .x86_64 }),
    });

    const kernel_tests_options = std.Build.TestOptions{
        .name = "BuddyAllocatorTests",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/AllTests.zig"),
            .target = b.resolveTargetQuery(.{ .cpu_arch = .x86_64 }),
        }),
    };

    const kernel_tests = b.addTest(kernel_tests_options);
    kernel_tests.root_module.addImport("Kernel", kernel_module);

    const run_kernel_tests = b.addRunArtifact(kernel_tests);

    const kernel_tests_step = b.step("tests", "run tests");
    kernel_tests_step.dependOn(&run_kernel_tests.step);

    b.installArtifact(kernel);
    b.installArtifact(exe);
}
