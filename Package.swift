// swift-tools-version: 6.2
//
// SB-Skin — third-party skins for the sing-box Apple clients.
// Licensed under GPL-3.0-or-later. See LICENSE and COPYING.

import PackageDescription

let package = Package(
    name: "SBSkin",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v26),
        .macOS(.v26),
    ],
    products: [
        // Main app UI: skin switcher, eight skins, shared pages.
        .library(name: "SBSkin", targets: ["SBSkin"]),
        // Widget extension UI: Live Activity, Dynamic Island, home and lock screen widgets.
        .library(name: "SBSkinWidgets", targets: ["SBSkinWidgets"]),
    ],
    targets: [
        .target(
            name: "SBSkinShared",
            resources: [.process("Resources")],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .target(
            name: "SBSkin",
            dependencies: ["SBSkinShared"],
            resources: [.process("Resources")],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .target(
            name: "SBSkinWidgets",
            dependencies: ["SBSkinShared"],
            resources: [.process("Resources")],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "SBSkinTests",
            dependencies: ["SBSkin", "SBSkinShared"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
