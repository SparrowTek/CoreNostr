// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CoreNostr",
    platforms: [.macOS(.v10_15), .iOS(.v13), .tvOS(.v13), .watchOS(.v6), .macCatalyst(.v13)],
    products: [
        .library(
            name: "CoreNostr",
            targets: ["CoreNostr"]),
    ],
    dependencies: [
        .package(url: "https://github.com/21-DOT-DEV/swift-secp256k1", from: "0.21.1"),
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.4.0"),
    ],
    targets: [
        .target(
            name: "CoreNostr",
            dependencies: [
                .product(name: "P256K", package: "swift-secp256k1"),
                .product(name: "Crypto", package: "swift-crypto"),
            ]),
        .testTarget(
            name: "CoreNostrTests",
            dependencies: ["CoreNostr"]
        ),
    ]
)
