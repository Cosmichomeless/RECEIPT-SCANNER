// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ReceiptKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "ReceiptKit", targets: ["ReceiptKit"])
    ],
    targets: [
        .target(name: "ReceiptKit"),
        .testTarget(
            name: "ReceiptKitTests",
            dependencies: ["ReceiptKit"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
