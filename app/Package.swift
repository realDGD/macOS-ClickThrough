// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ClickThrough",
    platforms: [.macOS("14.0")],
    products: [.executable(name: "ClickThrough", targets: ["ClickThrough"])],
    targets: [
        .target(name: "ClickThroughCore"),
        .executableTarget(name: "ClickThrough", dependencies: ["ClickThroughCore"]),
        .testTarget(name: "ClickThroughCoreTests", dependencies: ["ClickThroughCore"])
    ]
)
