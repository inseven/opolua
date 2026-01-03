// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "OpoLuaCore",
    platforms: [
        .iOS(.v15),
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "OpoLuaCore",
            targets: [
                "OpoLuaCore",
                "OplCore",
            ]),
    ],
    dependencies: [
        .package(path: "dependencies/LuaSwift"),
        .package(url: "https://github.com/inseven/licensable", from: "0.0.13"),
    ],
    targets: [
        .target(
            name: "OpoLuaCore",
            dependencies: [
                .product(name: "Licensable", package: "licensable"),
                .product(name: "Lua", package: "LuaSwift"),
                "OplCore",
                "OpoLuaLicenses",
                "OpoLuaSource",
            ],
            path: "core/swift"),
        .target(
            name: "OpoLuaLicenses",
            path: "core/licenses",
            resources: [
                .copy("lua-license"),
                .copy("opolua-license"),
            ]),
        .target(
            name: "OpoLuaSource",
            path: "core/src",
            resources: [
                .copy("aif.lua"),
                .copy("cmdline.lua"),
                .copy("compiler.lua"),
                .copy("const.lua"),
                .copy("cp1252.lua"),
                .copy("crc.lua"),
                .copy("database.lua"),
                .copy("defaultiohandler.lua"),
                .copy("dialog.lua"),
                .copy("directfilestore.lua"),
                .copy("editor.lua"),
                .copy("fns.lua"),
                .copy("genalaw.lua"),
                .copy("genstubs.lua"),
                .copy("includes"),
                .copy("init_dump.lua"),
                .copy("init.lua"),
                .copy("launcher.lua"),
                .copy("mbm.lua"),
                .copy("memory.lua"),
                .copy("menu.lua"),
                .copy("modules"),
                .copy("opl.lua"),
                .copy("opofile.lua"),
                .copy("ops.lua"),
                .copy("opx"),
                .copy("recognizer.lua"),
                .copy("rsc.lua"),
                .copy("runtime.lua"),
                .copy("scrollbar.lua"),
                .copy("sibosyscalls.lua"),
                .copy("sis.lua"),
                .copy("sound.lua"),
                .copy("stack.lua"),
                .copy("struct.lua"),
                .copy("tbench_bnot.lua"),
                .copy("tbench_typenumber.lua"),
                .copy("tcompiler.lua"),
                .copy("tmemory.lua"),
                .copy("unittest.lua"),
            ]),
        .target(
            name: "OplCore",
            path: "core/shared",
            publicHeadersPath: "include"
            ),
    ]
)
