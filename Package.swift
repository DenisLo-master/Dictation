// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Dictation",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Dictation", targets: ["DictationApp"])
    ],
    targets: [
        .executableTarget(
            name: "DictationApp",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("Carbon"),
                .linkedFramework("Security"),
                .linkedFramework("ServiceManagement")
            ]
        )
    ]
)
