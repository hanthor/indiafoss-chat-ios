// swift-tools-version:5.9
// The mesh medium for this app: the embedded Neutrino homeserver plus the
// iroh transport, built by hanthor/neutrino-iroh's Apple workflow. The binary
// target is the XCFramework that workflow publishes (device + simulator
// static libraries); the source target is the uniffi-generated Swift for both
// namespaces, vendored at the same revision — the two must move together.
import PackageDescription

let package = Package(
    name: "NeutrinoKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "NeutrinoKit", targets: ["NeutrinoKit"])
    ],
    targets: [
        .binaryTarget(
            name: "NeutrinoKitFFI",
            url: "https://github.com/hanthor/neutrino-iroh/releases/download/neutrino-kit-c2d3411/NeutrinoKit.xcframework.zip",
            checksum: "b8dbf3e08bfdda82fba86bd746c8f4db73968b02cf5b7b86a9fd65cf08a700f1"
        ),
        .target(
            name: "NeutrinoKit",
            dependencies: ["NeutrinoKitFFI"],
            path: "Sources/NeutrinoKit"
        ),
    ]
)
