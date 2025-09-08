// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CoreNostr",
    platforms: [
        .macOS(.v15),
        .iOS(.v17),
        .tvOS(.v17),
        .watchOS(.v10),
        .macCatalyst(.v17)
    ],
    products: [
        .library(
            name: "CoreNostr",
            targets: ["CoreNostr"]),
    ],
    dependencies: [
        .package(url: "https://github.com/21-DOT-DEV/swift-secp256k1", from: "0.21.1"),
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.4.0"),
        .package(url: "https://github.com/attaswift/BigInt.git", from: "5.6.0"),
        .package(url: "https://github.com/bitcoindevkit/bdk-swift.git", from: "2.0.0"),
        .package(url: "https://github.com/valpackett/SwiftCBOR.git", from: "0.5.0"),
        .package(url: "https://github.com/SparrowTek/Vault.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.3.0"),
    ],
    targets: [
        .target(
            name: "CoreNostr",
            dependencies: [
                .product(name: "P256K", package: "swift-secp256k1"),
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "BigInt", package: "BigInt"),
                .product(name: "BitcoinDevKit", package: "bdk-swift"),
                .product(name: "SwiftCBOR", package: "SwiftCBOR"),
                .product(name: "Vault", package: "Vault"),
            ]),
        .testTarget(
            name: "CoreNostrTests",
            dependencies: ["CoreNostr"]
        ),
    ]
)
