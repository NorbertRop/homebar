// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HomeBar",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "HomeBarCore", targets: ["HomeBarCore"]),
        .executable(name: "homebar", targets: ["HomeBar"]),
        .executable(name: "homebarcli", targets: ["homebarcli"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0"),
    ],
    targets: [
        .target(name: "HomeBarCore"),
        .testTarget(
            name: "HomeBarCoreTests",
            dependencies: ["HomeBarCore"],
            resources: [.copy("Fixtures")]
        ),
        .executableTarget(
            name: "HomeBar",
            dependencies: ["HomeBarCore", .product(name: "Sparkle", package: "Sparkle")],
            exclude: ["Info.plist"]
        ),
        .executableTarget(
            name: "homebarcli",
            dependencies: [
                "HomeBarCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
    ]
)
