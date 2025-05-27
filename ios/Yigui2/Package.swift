// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "Yigui2",
    platforms: [
        .iOS(.v15)
    ],
    dependencies: [
        .package(url: "https://github.com/magicien/GLTFSceneKit.git", .upToNextMajor(from: "0.4.0"))
    ],
    targets: [
        .target(
            name: "Yigui2",
            dependencies: ["GLTFSceneKit"]
        )
    ]
)
