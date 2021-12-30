// swift-tools-version:5.5

import PackageDescription

let package = Package(
    name: "FrameRecorder",
    platforms: [.iOS(.v15), .macOS(.v12)],
    products: [
        .library(name: "FrameRecorder", targets: ["FrameRecorder"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "FrameRecorder",
            dependencies: []),
        .testTarget(
            name: "FrameRecorderTests",
            dependencies: ["FrameRecorder"]),
    ]
)
