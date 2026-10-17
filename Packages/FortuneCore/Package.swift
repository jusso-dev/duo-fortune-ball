// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FortuneCore",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "FortuneCore", targets: ["FortuneCore"])
    ],
    targets: [
        .target(name: "FortuneCore"),
        .testTarget(name: "FortuneCoreTests", dependencies: ["FortuneCore"])
    ]
)
