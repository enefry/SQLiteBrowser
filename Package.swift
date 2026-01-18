// swift-tools-version:5.9

import PackageDescription

let package = Package(
  name: "SQLiteBrowser",
  platforms: [
    .iOS(.v15),
    .macOS(.v12),
  ],
  products: [
    .library(name: "SQLiteBrowser", targets: ["SQLiteBrowser"]),
  ],
  dependencies: [
    .package(url: "https://github.com/enefry/ConcurrencyCollection.git", from: "0.0.4"),
    .package(url: "https://github.com/enefry/LoggerProxy.git", from: "2.0.0"),
    .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.7.0"),
  ],
  targets: [
    .target(
        name: "SQLiteBrowser",
        dependencies: [
            .product(name: "ConcurrencyCollection", package: "ConcurrencyCollection"),
            .product(name: "LoggerProxy",package: "LoggerProxy"),
            .product(name: "GRDB",package: "GRDB.swift"),
        ],
        path: "SQLiteBrowser",
        resources: [
            .process("Assets.xcassets")
        ],
        swiftSettings:[SwiftSetting.define("SQLiteBrowserMacro"),SwiftSetting.define("macCatalyst",.when(platforms: [.macCatalyst]))],
        linkerSettings: [
            .linkedFramework("Foundation"),
            .linkedFramework("SwiftUI"),
            .linkedFramework("Combine"),
        ]
    )
  ]
)
