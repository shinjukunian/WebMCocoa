// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "VPX",
    products: [
        .library(
            name: "VPX",
            targets: ["VPX"]),
    ],
    dependencies: [],
    targets: [
        .binaryTarget(name: "WebM", path: "Sources/libWebM/WebM.xcframework"),
        
        .binaryTarget(name: "libVPX", path: "Sources/libVPX/VPX.xcframework"),
        
        .target(name: "VPXEncoder", dependencies: ["WebM", "libVPX"], path: nil, exclude: [String](), sources: nil, resources: nil, publicHeadersPath: nil, cSettings: [nil], cxxSettings: nil, swiftSettings: nil, linkerSettings: nil),
            
    ]
)

