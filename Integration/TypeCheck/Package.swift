// swift-tools-version: 6.2
//
// Type-checks Integration/Apple against signature stubs of the upstream sing-box Apple
// client (Libbox, Library, ApplicationLibrary). The stubs only mirror the declarations the
// integration uses, copied from upstream; they contain no behavior. Run:
//
//     swift build --package-path Integration/TypeCheck
//
// A real build inside the upstream Xcode project is still the source of truth.

import PackageDescription

let package = Package(
    name: "SkywaveIntegrationTypeCheck",
    platforms: [.iOS(.v26), .macOS(.v26)],
    targets: [
        // Skywave itself, via symlinks to ../../Sources, so the package identity does not
        // depend on the checkout folder name.
        .target(name: "SkywaveShared", resources: [.process("Resources")], swiftSettings: [.swiftLanguageMode(.v5)]),
        .target(name: "Skywave", dependencies: ["SkywaveShared"], resources: [.process("Resources")], swiftSettings: [.swiftLanguageMode(.v5)]),
        .target(name: "Libbox", swiftSettings: [.swiftLanguageMode(.v5)]),
        .target(name: "Library", dependencies: ["Libbox"], swiftSettings: [.swiftLanguageMode(.v5)]),
        .target(name: "ApplicationLibrary", dependencies: ["Library", "Libbox"], swiftSettings: [.swiftLanguageMode(.v5)]),
        .target(
            name: "IntegrationUnderTest",
            dependencies: ["Libbox", "Library", "ApplicationLibrary", "Skywave"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
