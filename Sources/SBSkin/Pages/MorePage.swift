import SBSkinShared
import SwiftUI

/// “Settings / More”: the same list in every skin. Appearance is ours; everything else links
/// to the unchanged upstream screens injected by the host.
struct MorePage: View {
    @Environment(SkinStore.self) private var store
    @Environment(SkinPreferences.self) private var preferences
    @Environment(\.skinTheme) private var theme
    @Environment(\.skinConfiguration) private var configuration
    var title: String?

    var body: some View {
        let pages = configuration.hostPages
        List {
            Section(SkinL("Profile")) {
                NavigationLink {
                    ProfilesPage(dismissesOnSelect: false)
                } label: {
                    row(SkinL("Current Profile"), value: store.activeProfile?.name ?? SkinL("None"), symbol: "doc.text")
                }
                if let profiles = pages.profiles {
                    NavigationLink { profiles() } label: {
                        row(SkinL("Manage Profiles"), symbol: "slider.horizontal.3")
                    }
                }
            }
            .listRowBackground(theme.surface)

            Section(SkinL("Appearance")) {
                NavigationLink {
                    AppearancePage()
                } label: {
                    row(SkinL("Skin"), value: preferences.skin.displayName, symbol: "paintpalette")
                }
            }
            .listRowBackground(theme.surface)

            Section(SkinL("Activity")) {
                NavigationLink { ConnectionsPage() } label: {
                    row(SkinL("Connections"), value: store.isRunning ? "\(store.activeConnections.count)" : nil, symbol: "arrow.left.arrow.right")
                }
                NavigationLink { LogsPage() } label: {
                    row(SkinL("Logs"), symbol: "list.bullet.rectangle")
                }
                NavigationLink { NodesPage() } label: {
                    row(SkinL("Outbound Groups"), symbol: "square.grid.3x3")
                }
            }
            .listRowBackground(theme.surface)

            if pages.tools != nil || pages.settings != nil || pages.remoteControl != nil {
                Section(SkinL("App")) {
                    if let tools = pages.tools {
                        NavigationLink { tools() } label: {
                            row(SkinL("Tools"), symbol: "wrench.and.screwdriver")
                                .badge(pages.toolsBadge())
                        }
                    }
                    if let remote = pages.remoteControl {
                        NavigationLink { remote() } label: {
                            row(SkinL("Remote Control"), symbol: "antenna.radiowaves.left.and.right")
                        }
                    }
                    if let settings = pages.settings {
                        NavigationLink { settings() } label: {
                            row(SkinL("Settings"), symbol: "gearshape")
                        }
                    }
                }
                .listRowBackground(theme.surface)
            }

            Section {
                AboutSkinsRow(appName: configuration.appName)
            }
            .listRowBackground(theme.surface)
        }
        .scrollContentBackground(.hidden)
        .background(theme.background)
        .navigationTitle(title ?? SkinL("Settings"))
    }

    private func row(_ title: String, value: String? = nil, symbol: String) -> some View {
        HStack {
            Label {
                Text(title).foregroundStyle(theme.text)
            } icon: {
                Image(systemName: symbol).foregroundStyle(theme.accent)
            }
            Spacer()
            if let value {
                Text(value).foregroundStyle(theme.secondaryText).lineLimit(1)
            }
        }
    }
}

struct AboutSkinsRow: View {
    @Environment(\.skinTheme) private var theme
    let appName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(appName).font(theme.font(.headline)).foregroundStyle(theme.text)
            Text(skin: "Skins by SB-Skin, free software under GPL-3.0-or-later.")
                .font(.caption)
                .foregroundStyle(theme.secondaryText)
            Link(destination: URL(string: "https://github.com/SadNoo/SB-Skin")!) {
                Text(verbatim: "github.com/SadNoo/SB-Skin").font(.caption)
            }
        }
        .padding(.vertical, 4)
    }
}
