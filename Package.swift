// swift-tools-version: 5.6

import PackageDescription

let package = Package(
    name: "ReactiveListDatasource",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "ReactiveListDatasource",
            targets: ["ReactiveListDatasource"]),
    ],
    dependencies: [
        .package(url: "https://github.com/ReactiveCocoa/ReactiveSwift.git", from: "7.0.0"),
        .package(url: "https://github.com/hyperoslo/Cache.git", from: "6.0.0"),
        .package(url: "https://github.com/jflinter/Dwifft.git", branch: "master")
    ],
    targets: [
        .target(
            name: "ReactiveListDatasource",
            dependencies: ["Cache", "Dwifft", "ReactiveSwift"]),
        .testTarget(
            name: "ReactiveListDatasourceTests",
            dependencies: ["ReactiveListDatasource"]),
    ]
)
