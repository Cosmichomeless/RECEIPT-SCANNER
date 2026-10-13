// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ReceiptKit",
    defaultLocalization: "en",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "ReceiptKit", targets: ["ReceiptKit"])
    ],
    targets: [
        .target(name: "ReceiptKit", resources: [.process("Resources")]),
        .testTarget(
            name: "ReceiptKitTests",
            dependencies: ["ReceiptKit"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
