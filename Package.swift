// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Nardy3D",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Nardy3D",
            resources: [
                .copy("Resources/Shaders"),
                .copy("Resources/nardy3d.png"),
                .copy("Resources/long.net"),
                .copy("Resources/short.net"),
            ]
        ),
    ]
)
