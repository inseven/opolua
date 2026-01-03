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
            ],
            path: "core/swift"),
        .target(
            name: "OpoLuaLicenses",
            path: "core/licenses",
            resources: [
                .process("lua-license"),
                .process("opolua-license"),
            ]),
        .target(
            name: "OplCore",
            path: "core/shared",
            publicHeadersPath: "include"
            ),
    ]
)
