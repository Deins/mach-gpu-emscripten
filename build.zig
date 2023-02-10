const std = @import("std");
const glfw = @import("libs/mach-glfw/build.zig");
const gpu_dawn_sdk = @import("libs/mach-gpu-dawn/sdk.zig");
const gpu_sdk = @import("sdk.zig");
const system_sdk = @import("libs/mach-glfw/system_sdk.zig");

pub fn build(b: *std.build.Builder) !void {
    const is_emscripten = b.option(bool, "emscripten", "Build with emscripten toolchain for web") orelse false;
    const mode = b.standardReleaseOptions();
    const target = b.standardTargetOptions(.{});
    const gpu_dawn = gpu_dawn_sdk.Sdk(.{
        .glfw = glfw,
        .glfw_include_dir = "libs/mach-glfw/upstream/glfw/include",
        .system_sdk = system_sdk,
    });
    const gpu = gpu_sdk.Sdk(.{
        .glfw = glfw,
        .gpu_dawn = gpu_dawn,
    });

    const gpu_dawn_options = gpu_dawn.Options{
        .from_source = b.option(bool, "dawn-from-source", "Build Dawn from source") orelse false,
        .debug = b.option(bool, "dawn-debug", "Use a debug build of Dawn") orelse false,
    };

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&(try gpu.testStep(b, mode, target, .{ .gpu_dawn_options = gpu_dawn_options })).step);

    const example = if (is_emscripten) b.addStaticLibrary("gpu-hello-triangle", "examples/main.zig") else b.addExecutable("gpu-hello-triangle", "examples/main.zig");
    example.setBuildMode(mode);
    example.setTarget(target);
    example.addPackage(gpu.pkg);
    example.addPackage(glfw.pkg);
    try gpu.link(b, example, .{ .gpu_dawn_options = gpu_dawn_options });
    if (is_emscripten) {
        emscripten_install(b, example) catch unreachable;
    } else {
        example.install();

        const example_run_cmd = example.run();
        example_run_cmd.step.dependOn(b.getInstallStep());
        const example_run_step = b.step("run-example", "Run the example");
        example_run_step.dependOn(&example_run_cmd.step);
    }
}

fn emscripten_install(b: *std.build.Builder, target : std.Build.CrossTarget, mode : std.Build.Mode, exe: *std.build.LibExeObjStep) !void {
    if (target.getCpuArch() != .wasm32 and target.getCpuArch() != .wasm64) @panic("Invalid target! Use -Dtarget=wasm32-freestanding or other wasm target.");
    const emsdk_path = b.env_map.get("EMSDK") orelse @panic("Can't find emscripten SDK path - have you sourced or added EMSDK to your path?");
    const emscripten_include = b.pathJoin(&.{ emsdk_path, "upstream", "emscripten", "cache", "sysroot", "include" });
    exe.addSystemIncludePath(emscripten_include);
    const emlink = b.addSystemCommand(&.{"emcc"});
    emlink.addArtifactArg(exe);
    const out_path = b.pathJoin(&.{ b.pathFromRoot("."), "zig-out", "www", exe.name });
    b.makePath(out_path) catch unreachable;
    const out_file = try std.mem.concat(b.allocator, u8, &.{ "-o", out_path, std.fs.path.sep_str ++ "index.html" });
    emlink.addArgs(&.{ "-sEXPORTED_FUNCTIONS=['_malloc','_free','_main','_preinitializedWebGPUDeviceReady']", "--no-entry" });
    //emling.addArgs(&.{"-sLLD_REPORT_UNDEFINED", "-sERROR_ON_UNDEFINED_SYMBOLS=0"});
    emlink.addArgs(&.{ out_file, "-sUSE_WEBGPU=1", "-sUSE_GLFW=3" });
    emlink.addArgs(&.{"-sASYNCIFY"});

    // TODO: didn't figure jet out why zig GeneralPurposeAllocator didn't work, might just be that custom one needs to be writen that uses _malloc & _free
    //const init_mem_mb: usize = 128;
    //emlink.addArgs(&.{ "-sINITIAL_MEMORY=" ++ std.fmt.comptimePrint("{}", .{init_mem_mb * 1024 * 1024}), "-sMALLOC=emmalloc", "-sABORTING_MALLOC=0" });

    // there are a lot of flags that can improve debuggingability, optimization, size,
    // these are basic defaults
    // for more details see: https://emscripten.org/docs/tools_reference/emcc.html#emccdoc
    switch (mode) {
        .Debug => {
            emlink.addArgs(&.{"-g"});
            const source_map_base = "./"; // depending on how webserver is configured this might need to be changed
            emlink.addArgs(&.{ "-gsource-map", "--source-map-base", source_map_base });
            //emlink.addArgs(&.{"-Og"});
        },
        .ReleaseSmall => emlink.addArgs(&.{"-Os"}),
        else => emlink.addArgs(&.{"-O3"}),
    }

    // custom html shell - it is required that WebGPU device is initialised from js
    emlink.addArgs(&.{ "--shell-file", "src/emscripten_shell.html" });

    // install linker step
    emlink.step.dependOn(&exe.step);
    b.getInstallStep().dependOn(&emlink.step);
}
