// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "VPX",
    platforms: [.macOS(.v10_13)],
    products: [
        .library(
            name: "VPX",
            targets: ["VPX"]),
    ],
    dependencies: [],
    targets: [
//        .binaryTarget(name: "WebM", path: "Sources/libWebM/WebM.xcframework"),
//        .binaryTarget(name: "libVPX", path: "Sources/libVPX/libVPX.xcframework"),
        
        .binaryTarget(name: "WebM",
                      url: "https://dl.bintray.com/shinjukunian/WebM-Cocoa/WebM.xcframework.zip",
                      checksum: "c0a68270eecf3ca41c96ef8a30384265cadff3a8a6ca9744fd35d38553b45e93"),
        
        .binaryTarget(name: "libVPX",
                      url: "https://dl.bintray.com/shinjukunian/WebM-Cocoa/libVPX.xcframework.zip",
                      checksum: "d382f9d9a7738a09cd592c268b4f04fc9826f933f4a03e82601ff652289f30d1"),
        
        .target(name: "VPX", dependencies: ["WebM", "libVPX"], path: nil, exclude: ["Info.plist"], sources: nil, resources: nil, publicHeadersPath: nil, cSettings: nil, cxxSettings: nil, swiftSettings: nil, linkerSettings: [.linkedFramework("Accelerate")]),
        
        .testTarget(name: "VPXTests", dependencies: ["VPX"], path: nil, exclude: ["Info.plist", "testData"], sources: nil, cSettings: nil, cxxSettings: nil, swiftSettings: nil, linkerSettings: nil),
        
    ]
)

