// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "HideNotch",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "HideNotch", path: "Sources/HideNotch")
    ]
)
