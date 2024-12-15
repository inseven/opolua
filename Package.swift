// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "OpoLua",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "OpoLua",
            targets: [
                "OpoLua"
            ]),
    ],
    dependencies: [
        .package(path: "LuaSwift"),
        .package(url: "https://github.com/inseven/licensable", from: "0.0.13"),
    ],
    targets: [
        .target(
            name: "OpoLua",
            dependencies: [
                .product(name: "Licensable", package: "licensable"),
                .product(name: "Lua", package: "LuaSwift"),
            ],
            path: ".",
            sources: [
                "swift",
            ],
            resources: [
                .process("swift-resources"),
            ],
            plugins: [
                .plugin(name: "EmbedLuaPlugin", package: "LuaSwift")
            ]),
    ]
)
