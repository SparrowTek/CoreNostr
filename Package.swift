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
        .package(url: "https://github.com/GigaBitcoin/secp256k1.swift.git", from: "0.17.0"),
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.4.0"),
    ],
    targets: [
        .target(
            name: "CoreNostr",
            dependencies: [
                .product(name: "secp256k1", package: "secp256k1.swift"),
                .product(name: "Crypto", package: "swift-crypto"),
            ]),
        .testTarget(
            name: "CoreNostrTests",
            dependencies: ["CoreNostr"]
        ),
    ]
)
