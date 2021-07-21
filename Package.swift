// swift-tools-version:5.4

import PackageDescription

let package = Package(
    name: "FrameRecorder",
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
