// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "nrf_mesh_flutter",
    platforms: [
        .iOS("13.0"),
    ],
    products: [
        // If the plugin name contains "_", replace with "-" for the library name.
        .library(name: "nrf-mesh-flutter", targets: ["nrf_mesh_flutter"]),
    ],
    dependencies: [
        // Flutter tooling generates this local package when SPM is enabled.
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
        // Nordic iOS Mesh library (provides the `NordicMesh` module used by this plugin).
        .package(url: "https://github.com/NordicSemiconductor/IOS-nRF-Mesh-Library", from: "4.8.0"),
    ],
    targets: [
        .target(
            name: "nrf_mesh_flutter",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                .product(name: "NordicMesh", package: "IOS-nRF-Mesh-Library"),
            ],
            path: "../Classes",
            exclude: [
                // These are only used by CocoaPods builds; SwiftPM consumes the Swift file instead.
                "PigeonGenerated.h",
                "PigeonGenerated.m",
            ],
            resources: [
                .process("PrivacyInfo.xcprivacy"),
            ]
        ),
    ]
)

