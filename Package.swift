// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "waygate",
    products: [
        .library(name: "WayGate", targets: ["WayGate"]),
        .executable(name: "waygate", targets: ["WayGateCLI"])
    ],
    dependencies: [
        .package(url: "https://github.com/bedrock-swift/nethernet.git", revision: "0906e3d3f6e5cfa9003371052cc89eb0ec0a2550"),
        .package(url: "https://github.com/bedrock-swift/raknet.git", revision: "49151d10ed2d40f6d8279fafb8b2b747b2385aa7"),
        .package(url: "https://github.com/apple/swift-crypto.git", exact: "4.5.2"),
        .package(url: "https://github.com/krzyzanowskim/CryptoSwift.git", exact: "1.9.0")
    ],
    targets: [
        .target(name: "WayGate", dependencies: [
            .product(name: "NetherNet", package: "nethernet"),
            .product(name: "RakNet", package: "raknet"),
            .product(name: "Crypto", package: "swift-crypto"),
            .product(name: "CryptoExtras", package: "swift-crypto"),
            "CryptoSwift"
        ]),
        .executableTarget(name: "WayGateCLI", dependencies: ["WayGate", .product(name: "RakNet", package: "raknet")]),
        .testTarget(name: "WayGateTests", dependencies: [
            "WayGate", .product(name: "RakNet", package: "raknet"), .product(name: "NetherNet", package: "nethernet"),
            .product(name: "Crypto", package: "swift-crypto"),
            .product(name: "CryptoExtras", package: "swift-crypto")
        ])
    ]
)
