import SBSkin
import SwiftUI

/// Demo host for SB-Skin. Runs every skin on sample data from `MockSkinBackend`, so the skins
/// can be tried on iPhone, iPad and Mac without building sing-box.
///
/// Launch arguments (handy for screenshots):
///   -sbskin-skin <native|instrument|focus|places|lens|sentence|radio|bento>
///   -sbskin-scenario <live|frozen|stopped|empty>
///   -sbskin-onboarding          show the first-launch picker again
@main
struct DemoApp: App {
    @State private var session = DemoApp.makeSession()

    var body: some Scene {
        WindowGroup {
            SkinRootView(session: session)
        }
        #if os(macOS)
        .defaultSize(width: 1280, height: 820)
        #endif
    }

    @MainActor
    private static func makeSession() -> SkinSession {
        let arguments = ProcessInfo.processInfo.arguments
        func value(after flag: String) -> String? {
            guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else { return nil }
            return arguments[index + 1]
        }
        let scenario: MockSkinBackend.Scenario = switch value(after: "-sbskin-scenario") {
        case "frozen": .frozen
        case "stopped": .stopped
        case "empty": .empty
        default: .live
        }
        let preferences = SkinPreferences()
        if let raw = value(after: "-sbskin-skin"), let skin = SkinID(rawValue: raw) {
            preferences.skin = skin
            preferences.hasChosenSkin = true
        }
        if arguments.contains("-sbskin-onboarding") {
            preferences.hasChosenSkin = false
        }
        let configuration = SkinConfiguration(
            appName: "Skin Demo",
            deepLinkScheme: "sbskindemo",
            hostPages: SkinHostPages(
                profiles: { AnyView(DemoHostPage(title: "Profiles", symbol: "doc.text", detail: "In the real app this is the upstream profile manager: create, import from link / file / QR code, edit, share, update and delete profiles.")) },
                tools: { AnyView(DemoHostPage(title: "Tools", symbol: "wrench.and.screwdriver", detail: "In the real app this is the upstream Tools screen: network quality, STUN test, Tailscale, SSH terminal, Taildrop, USB/IP, OpenVPN, OpenConnect and crash / OOM / power reports.")) },
                settings: { AnyView(DemoHostPage(title: "Settings", symbol: "gearshape", detail: "In the real app this is the upstream Settings screen: app, core, packet tunnel, on-demand rules, profile override, per-app proxy and about.")) },
                toolsBadge: { 1 }
            )
        )
        return SkinSession(backend: MockSkinBackend(scenario: scenario), configuration: configuration, preferences: preferences)
    }
}

/// Stand-in for an upstream screen.
private struct DemoHostPage: View {
    let title: String
    let symbol: String
    let detail: String

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: symbol)
        } description: {
            Text(detail)
        }
        .navigationTitle(title)
    }
}
