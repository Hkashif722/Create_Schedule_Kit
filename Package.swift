// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Create_Schedule_Kit",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "Create_Schedule_Kit",
            targets: ["Create_Schedule_Kit"]
        )
    ],
    dependencies: [
        .package(
            url: "https://dev.azure.com/EnthralltechDevOps/IOS_APIManager/_git/IOS_APIManager",
            branch: "add_download_method_bug_fixes"
        ),
        .package(
            url: "https://github.com/Hkashif722/SwiftUIUtility",
            branch: "update"
        ),
        .package(
            url: "https://github.com/Hkashif722/PopoverUtility.git",
            .upToNextMinor(from: "1.0.0")
        ),
        // same branch IOS-OGT_Package pins. two branches of one pkg = spm wont resolve the app
        .package(
            url: "https://github.com/Hkashif722/AssessmenyKitPackage.git",
            branch: "wcag_changes"
        )
    ],
    targets: [
        .target(
            name: "Create_Schedule_Kit",
            dependencies: [
                .product(name: "NetworkService", package: "IOS_APIManager"),
                .product(name: "SwiftUIUtilities", package: "SwiftUIUtility"),
                .product(name: "PopoverUtility", package: "PopoverUtility"),
                .product(name: "AssessmentKit", package: "AssessmenyKitPackage")
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "Create_Schedule_KitTests",
            dependencies: [
                "Create_Schedule_Kit",
                .product(name: "NetworkService", package: "IOS_APIManager"),
                .product(name: "SwiftUIUtilities", package: "SwiftUIUtility")
            ]
        )
    ]
)
