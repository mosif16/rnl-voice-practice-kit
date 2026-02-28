// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "VoicePracticeKit",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "VoicePracticeKit",
            targets: ["VoicePracticeKit"]
        )
    ],
    targets: [
        .target(
            name: "VoicePracticeKit"
        ),
        .testTarget(
            name: "VoicePracticeKitTests",
            dependencies: ["VoicePracticeKit"]
        )
    ]
)
