// swift-tools-version: 6.0
import PackageDescription

// Foundation-only policies can be tested on a Mac without the iOS SDK.
let package = Package(
    name: "LockInCore",
    platforms: [.macOS(.v13)],
    products: [.library(name: "LockInCore", targets: ["LockInCore"])],
    targets: [
        .target(name: "LockInCore", path: "FocusApp/Core", exclude: ["Models.swift", "SharedStore.swift", "ShieldPolicy.swift", "BlockingController.swift"], sources: ["TimePolicy.swift", "LifeModels.swift"]),
        .testTarget(name: "LockInCoreTests", dependencies: ["LockInCore"], path: "FocusAppTests", exclude: ["SharedStoreTests.swift"], sources: ["TimePolicyTests.swift", "LifeStoreTests.swift"])
    ]
)
