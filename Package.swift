// swift-tools-version: 6.2
//
// Skywave — third-party skins for the sing-box Apple clients.
// Licensed under GPL-3.0-or-later. See LICENSE and COPYING.

import PackageDescription

let package = Package(
    name: "Skywave",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v26),
        .macOS(.v26),
    ],
    products: [
        // Main app UI: skin switcher, eight skins, shared pages.
        .library(name: "Skywave", targets: ["Skywave"]),
        // Widget extension UI: Live Activity, Dynamic Island, home and lock screen widgets.
        .library(name: "SkywaveWidgets", targets: ["SkywaveWidgets"]),
    ],
    targets: [
        .target(
            name: "SkywaveShared",
            resources: [.process("Resources")],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .target(
            name: "Skywave",
            dependencies: ["SkywaveShared"],
            resources: [.process("Resources")],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .target(
            name: "SkywaveWidgets",
            dependencies: ["SkywaveShared"],
            resources: [.process("Resources")],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "SkywaveTests",
            dependencies: ["Skywave", "SkywaveShared"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
