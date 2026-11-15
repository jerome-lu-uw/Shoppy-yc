// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ShoppyCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "ShoppyCore", targets: ["ShoppyCore"]),
    ],
    targets: [
        .target(name: "ShoppyCore"),
        .testTarget(name: "ShoppyCoreTests", dependencies: ["ShoppyCore"]),
    ]
)
