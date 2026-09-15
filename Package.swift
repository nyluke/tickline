// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Tickline",
    platforms: [.macOS(.v13), .iOS(.v16)],
    products: [
        .library(name: "TicklineKit", targets: ["TicklineKit"])
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-markdown.git", from: "0.4.0")
    ],
    targets: [
        .target(
            name: "TicklineKit",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown")
            ]
        ),
        .executableTarget(
            name: "Tickline",
            dependencies: ["TicklineKit"]
        )
    ]
)
