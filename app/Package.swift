// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Openotes",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Openotes",
            path: "Sources/Openotes",
            exclude: ["Info.plist"]
        )
    ],
    swiftLanguageVersions: [.v5]
)
