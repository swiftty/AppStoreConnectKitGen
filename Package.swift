// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AppStoreConnectKitGen",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(
            name: "appstoreconnectgen",
            targets: ["appstoreconnectgen"])
    ],
    dependencies: [
        .package(url: "https://github.com/mattpolzin/OpenAPIKit", from: "4.3.1"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.7.0"),

        // devDependencies
        .package(url: "https://github.com/swiftty/SwiftLintBinary.git", from: "0.63.0"),
    ],
    targets: [
        .executableTarget(
            name: "appstoreconnectgen",
            dependencies: [
                "AppStoreConnectGenKit",
                "AppStoreConnectGenForSwift",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]),

        .target(
            name: "AppStoreConnectGenForSwift",
            dependencies: [
                "AppStoreConnectGenKit"
            ]),

        .testTarget(
            name: "AppStoreConnectGenForSwiftTests",
            dependencies: [
                "AppStoreConnectGenForSwift"
            ]),

        .target(
            name: "AppStoreConnectGenKit",
            dependencies: [
                .product(name: "OpenAPIKit30", package: "OpenAPIKit")
            ]
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
}
