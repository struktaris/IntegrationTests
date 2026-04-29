// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "IntegrationTests",
    platforms: [
        .macOS(.v15),
        .iOS(.v17),
        .tvOS(.v17),
        .watchOS(.v10),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "IntegrationTests",
            targets: ["IntegrationTests"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/stefanspringer1/SwiftUtilities", from: "6.2.17"),
        //.package(path: "../../stefanspringer1/SwiftUtilities"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "IntegrationTests",
            dependencies: [
                .product(name: "Utilities", package: "SwiftUtilities"),
            ]
        ),
        .testTarget(
            name: "IntegrationTestsTests",
            dependencies: ["IntegrationTests"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
