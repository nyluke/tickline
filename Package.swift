// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Tickline",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-markdown.git", from: "0.4.0")
    ],
    targets: [
        .executableTarget(
            name: "Tickline",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown")
            ]
        )
    ]
)
