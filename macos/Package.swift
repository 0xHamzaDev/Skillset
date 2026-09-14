// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Skillset",
    defaultLocalization: "en",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(name: "Skillset", path: "Sources/Skillset"),
        .testTarget(name: "SkillsetTests", dependencies: ["Skillset"], path: "Tests/SkillsetTests"),
    ]
)
