#if os(macOS)
    import AppKit
    import Foundation
    @testable import SBSkin
    import SwiftUI
    import Testing

    /// Renders every skin in a Mac-sized window to PNG files.
    ///
    ///     SBSKIN_SNAPSHOTS=/path/to/dir swift test --filter SnapshotTests
    ///
    /// Skipped unless `SBSKIN_SNAPSHOTS` is set, so normal test runs stay fast.
    @MainActor
    @Suite struct SnapshotTests {
        nonisolated static var outputDirectory: URL? {
            ProcessInfo.processInfo.environment["SBSKIN_SNAPSHOTS"].map { URL(fileURLWithPath: $0) }
        }

        @Test(.enabled(if: SnapshotTests.outputDirectory != nil), arguments: SkinID.allCases)
        func macWindow(skin: SkinID) async throws {
            let directory = try #require(Self.outputDirectory)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let appearance = ProcessInfo.processInfo.environment["SBSKIN_APPEARANCE"] == "dark" ? NSAppearance(named: .darkAqua) : NSAppearance(named: .aqua)
            let session = SkinSession.preview(.frozen, skin: skin)
            let size = NSSize(width: 1280, height: 820)
            let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.titled, .fullSizeContentView], backing: .buffered, defer: false)
            window.appearance = appearance
            let host = NSHostingView(rootView: SkinRootView(session: session).frame(width: size.width, height: size.height))
            window.contentView = host
            window.orderFrontRegardless()
            // Let SwiftUI lay out, load fonts and run a couple of animation frames.
            for _ in 0 ..< 20 {
                try await Task.sleep(for: .milliseconds(100))
                host.layoutSubtreeIfNeeded()
            }
            let rep = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
            host.cacheDisplay(in: host.bounds, to: rep)
            let data = try #require(rep.representation(using: .png, properties: [:]))
            try data.write(to: directory.appendingPathComponent("mac-\(skin.rawValue).png"))
            window.orderOut(nil)
        }
    }
#endif
