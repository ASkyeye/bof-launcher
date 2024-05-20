const bofs_included_in_launcher = [_]Bof{
    .{ .name = "helloBof", .formats = &.{.elf}, .archs = &.{ .x64, .x86, .aarch64, .arm } },
    .{ .name = "misc", .formats = &.{.elf}, .archs = &.{ .x64, .x86, .aarch64, .arm } },
    .{ .name = "udpScanner", .formats = &.{ .elf, .coff }, .archs = &.{ .x64, .x86, .aarch64, .arm } },
    .{ .name = "tcpScanner", .formats = &.{ .elf, .coff }, .archs = &.{ .x64, .x86, .aarch64, .arm } },
    .{ .name = "wWinver", .formats = &.{.coff}, .archs = &.{ .x64, .x86 } },
    .{ .name = "wWinverC", .formats = &.{.coff}, .archs = &.{ .x64, .x86 } },
    .{ .name = "wWhoami", .formats = &.{.coff}, .archs = &.{ .x64, .x86 } },
    .{ .name = "wDirectSyscall", .formats = &.{.coff}, .archs = &.{.x64} },
    .{ .name = "lAsmTest", .formats = &.{.elf}, .archs = &.{.x64} },
    .{ .name = "uname", .dir = "coreutils/", .formats = &.{.elf}, .archs = &.{ .x64, .x86, .aarch64, .arm } },
    .{ .name = "hostid", .dir = "coreutils/", .formats = &.{.elf}, .archs = &.{ .x64, .x86, .aarch64, .arm } },
    .{ .name = "hostname", .dir = "coreutils/", .formats = &.{.elf}, .archs = &.{ .x64, .x86, .aarch64, .arm } },
    .{ .name = "uptime", .dir = "coreutils/", .formats = &.{.elf}, .archs = &.{ .x64, .x86, .aarch64, .arm } },
    .{ .name = "id", .dir = "coreutils/", .formats = &.{.elf}, .archs = &.{ .x64, .x86, .aarch64, .arm } },
    .{ .name = "ifconfig", .dir = "net-tools/", .formats = &.{.elf}, .archs = &.{ .x64, .x86, .aarch64, .arm } },
    .{ .name = "wSimpleChainStage0", .dir = "simple-chain/", .formats = &.{.coff}, .archs = &.{ .x64, .x86 } },
    .{ .name = "wSimpleChainStage1", .dir = "simple-chain/", .formats = &.{.coff}, .archs = &.{ .x64, .x86 } },
    .{ .name = "wSimpleChainStage2", .dir = "simple-chain/", .formats = &.{.coff}, .archs = &.{ .x64, .x86 } },
    .{ .name = "wSimpleChainStage3", .dir = "simple-chain/", .formats = &.{.coff}, .archs = &.{ .x64, .x86 } },
    //.{ .name = "adcs_enum_com2", .go = "entry", .dir = "adcs_enum_com2/", .formats = &.{.coff}, .archs = &.{ .x64, .x86 } },
};

// Additional/3rdparty BOFs for building should be added below

//const bofs_my_custom = [_]Bof{
//    .{ .name = "bof1", .formats = &.{ .elf, .coff }, .archs = &.{ .x64, .x86, .aarch64, .arm } },
//    .{ .name = "bof2", .formats = &.{ .elf, .coff }, .archs = &.{ .x64, .x86, .aarch64, .arm } },
//};

fn addBofsToBuild(bofs_to_build: *std.ArrayList(Bof)) !void {
    try bofs_to_build.appendSlice(bofs_included_in_launcher[0..]);

    //try bofs_to_build.appendSlice(bofs_my_custom[0..]);
}

const std = @import("std");
const Options = @import("../build.zig").Options;

const BofLang = enum { zig, c, @"asm" };
const BofFormat = enum { coff, elf };
const BofArch = enum { x64, x86, aarch64, arm };

const Bof = struct {
    dir: ?[]const u8 = null,
    // source file name with go() function if in other file than .name
    go: ?[]const u8 = null,
    name: []const u8,
    formats: []const BofFormat,
    archs: []const BofArch,

    fn getTargetQuery(format: BofFormat, arch: BofArch) std.Target.Query {
        if (arch == .arm) {
            // We basically force ARMv6 here.
            return .{
                .cpu_arch = .arm,
                .os_tag = .linux,
                .abi = .gnueabihf,
                .cpu_model = .{ .explicit = &std.Target.arm.cpu.arm1176jz_s }, // ARMv6kz
            };
        }
        return .{
            .cpu_arch = switch (arch) {
                .x64 => .x86_64,
                .x86 => .x86,
                .aarch64 => .aarch64,
                .arm => .arm,
            },
            .os_tag = switch (format) {
                .coff => .windows,
                .elf => .linux,
            },
            .abi = if (arch == .arm) .gnueabihf else .gnu,
        };
    }
};

pub fn build(b: *std.Build, bof_api_module: *std.Build.Module) !void {
    var bofs_to_build = std.ArrayList(Bof).init(b.allocator);
    defer bofs_to_build.deinit();

    try addBofsToBuild(&bofs_to_build);

    try generateBofCollectionYaml(b.allocator, bofs_to_build);

    const windows_include_dir = try std.fs.path.join(
        b.allocator,
        &.{ std.fs.path.dirname(b.graph.zig_exe).?, "/lib/libc/include/any-windows-any" },
    );
    const linux_libc_include_dir = try std.fs.path.join(
        b.allocator,
        &.{ std.fs.path.dirname(b.graph.zig_exe).?, "/lib/libc/include/generic-glibc" },
    );
    const linux_any_include_dir = try std.fs.path.join(
        b.allocator,
        &.{ std.fs.path.dirname(b.graph.zig_exe).?, "/lib/libc/include/any-linux-any" },
    );

    for (bofs_to_build.items) |bof| {
        const source_file_path, const lang = try getBofSourcePathAndLang(b.allocator, bof);

        for (bof.formats) |format| {
            for (bof.archs) |arch| {
                if (format == .coff and arch == .aarch64) continue;
                if (format == .coff and arch == .arm) continue;

                const full_bof_name = try std.mem.join(
                    b.allocator,
                    ".",
                    &.{ bof.name, @tagName(format), @tagName(arch), "o" },
                );

                const bin_full_bof_name = try std.mem.join(b.allocator, "/", &.{ "bin", full_bof_name });

                if (lang == .@"asm") {
                    const run_fasm = b.addSystemCommand(&.{
                        thisDir() ++ "/../bin/fasm" ++ if (@import("builtin").os.tag == .windows) ".exe" else "",
                    });
                    run_fasm.addFileArg(.{ .path = source_file_path });
                    const output_path = run_fasm.addOutputFileArg(full_bof_name);

                    b.getInstallStep().dependOn(&b.addInstallFile(output_path, bin_full_bof_name).step);

                    continue; // This is all we need to do in case of asm BOF. Continue to the next BOF.
                }

                const target = b.resolveTargetQuery(Bof.getTargetQuery(format, arch));
                const obj = switch (lang) {
                    .@"asm" => unreachable,
                    .zig => b.addObject(.{
                        .name = bof.name,
                        .root_source_file = .{ .path = source_file_path },
                        .target = target,
                        .optimize = .ReleaseSmall,
                    }),
                    .c => blk: {
                        const obj = b.addObject(.{
                            .name = bof.name,
                            // TODO: Zig bug. Remove below line once fixed.
                            .root_source_file = .{ .path = thisDir() ++ "/../tests/src/dummy.zig" },
                            .target = target,
                            .optimize = .ReleaseSmall,
                        });
                        obj.addCSourceFile(.{
                            .file = .{ .path = source_file_path },
                            .flags = &.{ "-DBOF", "-D_GNU_SOURCE" },
                        });
                        if (format == .coff) {
                            obj.addIncludePath(.{ .path = windows_include_dir });
                        } else if (format == .elf) {
                            const linux_include_dir = try std.mem.join(
                                b.allocator,
                                "",
                                &.{
                                    std.fs.path.dirname(b.graph.zig_exe).?,
                                    "/lib/libc/include/",
                                    @tagName(target.result.cpu.arch),
                                    "-linux-",
                                    @tagName(target.result.abi),
                                },
                            );
                            obj.addIncludePath(.{ .path = linux_include_dir });
                            obj.addIncludePath(.{ .path = linux_libc_include_dir });
                            obj.addIncludePath(.{ .path = linux_any_include_dir });
                        }
                        break :blk obj;
                    },
                };
                obj.addIncludePath(.{ .path = thisDir() ++ "/../include" });
                obj.root_module.addImport("bof_api", bof_api_module);
                obj.root_module.pic = true;
                obj.root_module.single_threaded = true;
                obj.root_module.strip = true;
                obj.root_module.unwind_tables = false;

                b.getInstallStep().dependOn(&b.addInstallFile(obj.getEmittedBin(), bin_full_bof_name).step);
            }
        }
    }
}

fn generateBofCollectionYaml(
    allocator: std.mem.Allocator,
    bofs_to_build: std.ArrayList(Bof),
) !void {
    const doc_file = try std.fs.cwd().createFile("BOF-collection.yaml", .{});
    defer doc_file.close();

    for (bofs_to_build.items) |bof| {
        const source_file_path, const lang = try getBofSourcePathAndLang(allocator, bof);

        if (lang != .@"asm") {
            const source_file = try std.fs.openFileAbsolute(source_file_path, .{});
            defer source_file.close();

            const source = try source_file.readToEndAlloc(allocator, std.math.maxInt(u32));
            defer allocator.free(source);

            _ = std.mem.replace(u8, source, "\r\n", "\n", source);

            var line_number: u32 = 1;
            var iter = std.mem.splitSequence(u8, source, "\n");
            while (iter.next()) |source_line| {
                if (source_line.len >= 3 and std.mem.eql(u8, source_line[0..3], "///")) {
                    if (line_number == 1) try doc_file.writeAll("---\n");
                    line_number += 1;
                    try doc_file.writeAll(source_line[3..]);
                    try doc_file.writeAll("\n");
                }
            }
        }
    }
}

fn getBofSourcePathAndLang(
    allocator: std.mem.Allocator,
    bof: Bof,
) !struct { []const u8, BofLang } {
    const bof_src_path = try std.mem.join(
        allocator,
        "",
        &.{
            thisDir(),
            "/src/",
            if (bof.dir) |dir| dir else "",
            if (bof.go) |go| go else bof.name,
        },
    );

    const lang: BofLang = blk: {
        std.fs.accessAbsolute(
            try std.mem.join(allocator, ".", &.{ bof_src_path, "zig" }),
            .{},
        ) catch {
            std.fs.accessAbsolute(
                try std.mem.join(allocator, ".", &.{ bof_src_path, "asm" }),
                .{},
            ) catch break :blk .c;

            break :blk .@"asm";
        };
        break :blk .zig;
    };

    const source_file_path = try std.mem.join(allocator, ".", &.{ bof_src_path, @tagName(lang) });

    return .{ source_file_path, lang };
}

inline fn thisDir() []const u8 {
    return comptime std.fs.path.dirname(@src().file) orelse ".";
}
