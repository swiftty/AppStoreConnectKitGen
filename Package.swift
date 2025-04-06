// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AppStoreConnectKitGen",
    platforms: [
        .macOS(.v15),
    ],
    products: [
        .executable(
            name: "apigen",
            targets: ["apigen"]),
        .library(
            name: "AppStoreConnectKitGen",
            targets: ["AppStoreConnectKitGen"]),
    ],
    dependencies: [
        .package(url: "https://github.com/mattpolzin/OpenAPIKit", from: "3.4.2"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
        .package(url: "https://github.com/swiftlang/swift-syntax", from: "601.0.0"),

        // devDependencies
        .package(url: "https://github.com/swiftty/SwiftLintBinary.git", from: "0.59.0")
    ],
    targets: [
        .executableTarget(
            name: "apigen",
            dependencies: [
                "AppStoreConnectKitGen",
                "SwiftRenderer",

                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]),

        .target(
            name: "SwiftRenderer",
            dependencies: [
                "AppStoreConnectKitGen",

                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxBuilder", package: "swift-syntax")
            ]),

        .target(
            name: "AppStoreConnectKitGen",
            dependencies: [
                .product(name: "OpenAPIKit30", package: "OpenAPIKit")
            ]),
        .testTarget(
            name: "AppStoreConnectKitGenTests",
            dependencies: ["AppStoreConnectKitGen"]
        ),
    ]
)

for target in package.targets {
    do {
        var plugins = target.plugins ?? []
        plugins += [
            .plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintBinary")
        ]

        target.plugins = plugins

    }

    do {
        var swiftSettings = target.swiftSettings ?? []
        swiftSettings += [
            .enableUpcomingFeature("InternalImportsByDefault")
        ]
        target.swiftSettings = swiftSettings
    }
}
