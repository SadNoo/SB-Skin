// Skywave ⇄ sing-box Apple client: host glue.
//
// `SkinIntegrationRoot` replaces the upstream tab view / split view. Everything around it in
// the upstream MainView (alerts, global checks, URL handling, remote control restore…) stays.
//
// SPDX-License-Identifier: GPL-3.0-or-later

import ApplicationLibrary
import Foundation
import Library
import Skywave
import SwiftUI

@MainActor
public enum SkinIntegration {
    private static var cachedSession: SkinSession?

    /// One skin session per process, backed by the upstream environments.
    public static func session(for environments: ExtensionEnvironments) -> SkinSession {
        if let cachedSession { return cachedSession }
        let session = SkinSession(
            backend: UpstreamSkinBackend(environments: environments),
            configuration: configuration(for: environments)
        )
        cachedSession = session
        return session
    }

    /// Call first from the host's `onOpenURL`; returns true when the URL was a skin deep link
    /// (from a widget or the Live Activity) so the host can skip its own handling.
    public static func handle(_ url: URL, environments: ExtensionEnvironments) -> Bool {
        session(for: environments).handle(url)
    }

    private static func configuration(for environments: ExtensionEnvironments) -> SkinConfiguration {
        var pages = SkinHostPages(
            profiles: { AnyView(UpstreamProfilesPage()) },
            tools: { AnyView(ToolsView()) },
            settings: { AnyView(SettingView()) },
            toolsBadge: { environments.toolsBadgeCount }
        )
        #if os(iOS) || os(macOS)
            pages.remoteControl = { AnyView(RemoteControlView()) }
        #endif
        return SkinConfiguration(
            deepLinkScheme: firstURLScheme(),
            alternateIcons: SkinConfiguration.skywaveAlternateIcons,
            liveActivities: true,
            widgetSnapshots: true,
            hostPages: pages
        )
    }

    /// The first `CFBundleURLSchemes` entry of the host (upstream registers `sing-box`).
    private static func firstURLScheme() -> String? {
        let types = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]]
        return types?.lazy.compactMap { ($0["CFBundleURLSchemes"] as? [String])?.first }.first
    }
}

/// Drop-in replacement for the upstream root navigation.
public struct SkinIntegrationRoot: View {
    @EnvironmentObject private var environments: ExtensionEnvironments

    public init() {}

    public var body: some View {
        SkinRootView(session: SkinIntegration.session(for: environments))
            // Upstream shows this sheet from its dashboard; skins replace the dashboard.
            .sheet(item: $environments.pendingImportRemoteProfile) { request in
                NavigationSheet(title: String(localized: "Import Profile"), onDismiss: {
                    environments.profileUpdate.send()
                }, content: {
                    NewProfileView(.init(name: request.name, url: request.url))
                        .environmentObject(environments)
                })
            }
    }
}

/// Upstream profile management (create, import, pick, edit, update, share) on its own page.
struct UpstreamProfilesPage: View {
    @EnvironmentObject private var environments: ExtensionEnvironments
    @StateObject private var coordinator = DashboardViewModel()

    var body: some View {
        ScrollView {
            ProfileCard(
                profileList: $coordinator.profileList,
                selectedProfileID: Binding(
                    get: { coordinator.selectedProfileID },
                    set: { id in
                        coordinator.selectedProfileID = id
                        SkinIntegration.session(for: environments).store.selectProfile(id)
                    }
                )
            )
            .padding()
        }
        .navigationTitle(String(localized: "Profiles"))
        .onAppear {
            coordinator.setEnvironments(environments)
            Task { await coordinator.reload() }
        }
        .onReceive(environments.profileUpdate) { _ in
            Task { await coordinator.reload() }
        }
        .alert($coordinator.alert)
    }
}
