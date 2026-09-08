// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Pyno",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/FluidInference/FluidAudio.git", from: "0.15.6")
    ],
    targets: [
        .executableTarget(
            name: "Pyno",
            dependencies: [.product(name: "FluidAudio", package: "FluidAudio")],
            path: "Sources/Pyno",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
