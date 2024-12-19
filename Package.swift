// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let packageName = "BlackBoxFirebasePerformance"
let libraryName = packageName
let targetName = libraryName
let testTargetName = targetName + "Tests"

let package = Package(
    name: packageName,
    platforms: [
        .iOS(.v12),
        .tvOS(.v12)
    ],
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: libraryName,
            targets: [targetName]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(
            url: "https://github.com/dodobrands/BlackBox",
            .upToNextMajor(from: "4.0.1")
        ),
        .package(
            url: "https://github.com/firebase/firebase-ios-sdk",
            .upToNextMajor(from: "11.6.0")
        ),
        .package(
            url: "https://github.com/dodobrands/DBThreadSafe-ios",
            .upToNextMajor(from: "2.0.0")
        )
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: targetName,
            dependencies: [
                "BlackBox",
                .product(name: "FirebasePerformance", package: "firebase-ios-sdk"),
                .product(name: "DBThreadSafe", package: "DBThreadSafe-ios")
            ]
        ),
        .testTarget(
            name: testTargetName,
            dependencies: [
                .targetItem(name: targetName, condition: nil),
                "BlackBox",
                .product(name: "FirebasePerformance", package: "firebase-ios-sdk")
            ]
        ),
    ]
)
