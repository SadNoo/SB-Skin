import SBSkinShared
import SwiftUI

/// Dashboard for the Native skin. One column of grouped cards on iPhone; a card grid with a
/// large traffic chart on iPad and Mac.
struct NativeDashboard: View {
    @Environment(SkinStore.self) private var store
    @Environment(SkinRouter.self) private var router
    @Environment(\.skinTheme) private var theme
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.skinConfiguration) private var configuration

    var body: some View {
        ScrollView {
            Group {
                if !store.hasProfiles {
                    NoProfileView()
                } else if sizeClass == .regular {
                    regular
                } else {
                    compact
                }
            }
            .padding(.horizontal, sizeClass == .regular ? 24 : 16)
            .padding(.vertical, 12)
        }
        .background(theme.background)
        .navigationTitle(SkinL("Dashboard"))
        .toolbar {
            if sizeClass != .regular {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        router.sheet = .profiles
                    } label: {
                        Label(SkinL("Profiles"), systemImage: "doc.text")
                    }
                    .disabled(!store.hasProfiles)
                }
            }
        }
    }

    // MARK: iPhone

    private var compact: some View {
        VStack(spacing: 16) {
            NativeServiceCard()
            if store.isRunning {
                if store.clashModes.count > 1 {
                    NativeModePicker()
                }
                HStack(spacing: 12) {
                    NativeTrafficTile(title: SkinL("Upload"), symbol: "arrow.up", rate: store.status.uplink, history: store.uplinkHistory, color: theme.upload)
                    NativeTrafficTile(title: SkinL("Download"), symbol: "arrow.down", rate: store.status.downlink, history: store.downlinkHistory, color: theme.download)
                }
                NativeStatsCard()
                NativeCurrentNodeCard()
                if store.systemProxy.available {
                    NativeSystemProxyCard()
                }
            }
        }
    }

    // MARK: iPad / Mac

    private var regular: some View {
        VStack(spacing: 14) {
            if store.isRunning {
                HStack(alignment: .top, spacing: 14) {
                    NativeTrafficHero()
                        .frame(maxWidth: .infinity)
                    NativeCurrentNodeCard(prominent: true)
                        .frame(width: 280)
                }
                HStack(spacing: 14) {
                    NativeMetricTile(title: SkinL("Connections"), value: "\(store.status.totalConnections)", detail: SkinL("In %lld · Out %lld", store.status.connectionsIn, store.status.connectionsOut))
                    NativeMetricTile(title: SkinL("Memory"), value: SkinFormat.bytes(store.status.memory), detail: SkinL("Goroutines %lld", store.status.goroutines))
                    NativeMetricTile(title: SkinL("Uptime"), value: nil, detail: store.phase.label) {
                        ElapsedText(since: store.connectedSince)
                    }
                    if store.systemProxy.available {
                        NativeSystemProxyCard()
                    }
                }
                if let group = store.primaryGroup {
                    NativeGroupStrip(group: group)
                }
            } else {
                NativeServiceCard()
                    .frame(maxWidth: 560)
            }
        }
        .frame(maxWidth: 1200)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Cards

/// Profile + service switch.
private struct NativeServiceCard: View {
    @Environment(SkinStore.self) private var store
    @Environment(SkinRouter.self) private var router
    @Environment(\.skinTheme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            Button {
                router.sheet = .profiles
            } label: {
                HStack(spacing: 12) {
                    NativeIconTile(symbol: store.activeProfile?.isRemote == true ? "icloud.fill" : "doc.text.fill", color: theme.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.activeProfile?.name ?? SkinL("No Profile")).font(.body).foregroundStyle(theme.text)
                        Text(profileDetail).font(.footnote).foregroundStyle(theme.secondaryText)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 64)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Divider().padding(.leading, 64)
            HStack(spacing: 12) {
                NativeIconTile(symbol: "power", color: store.isRunning ? SkinPalette.good : .gray)
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.phase.label).font(.body).foregroundStyle(theme.text)
                    if store.isRunning {
                        HStack(spacing: 4) {
                            Text(skin: "Running")
                            ElapsedText(since: store.connectedSince)
                        }
                        .font(.footnote)
                        .foregroundStyle(theme.secondaryText)
                    }
                }
                Spacer()
                if store.phase.isTransitioning {
                    ProgressView()
                } else {
                    Toggle(SkinL("Service"), isOn: Binding(get: { store.phase.isActive }, set: { _ in store.toggleService() }))
                        .labelsHidden()
                        .tint(SkinPalette.good)
                }
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 64)
        }
        .background(theme.surface, in: RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous))
    }

    private var profileDetail: String {
        guard let profile = store.activeProfile else { return "" }
        if profile.isRemote, let date = profile.lastUpdated {
            return SkinL("Remote · updated %@", date.formatted(.relative(presentation: .named)))
        }
        return profile.isRemote ? SkinL("Remote") : SkinL("Local")
    }
}

struct NativeIconTile: View {
    let symbol: String
    let color: Color

    var body: some View {
        Image(systemName: symbol)
            .font(.body.weight(.semibold))
            .foregroundStyle(.white)
            .frame(width: 36, height: 36)
            .background(color, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct NativeModePicker: View {
    @Environment(SkinStore.self) private var store
    @Environment(SkinPreferences.self) private var preferences

    var body: some View {
        Picker(SkinL("Mode"), selection: Binding(get: { store.clashMode }, set: { store.setClashMode($0) })) {
            ForEach(store.clashModes, id: \.self) { mode in
                Text(preferences.vocabulary.modeShort(mode)).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .controlSize(.large)
    }
}

private struct NativeTrafficTile: View {
    @Environment(\.skinTheme) private var theme
    let title: String
    let symbol: String
    let rate: Int64
    let history: [Double]
    let color: Color

    var body: some View {
        let parts = SkinFormat.rateParts(rate)
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: symbol)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(theme.secondaryText)
                .labelStyle(TintedIconLabelStyle(color: color))
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(parts.value).font(.system(.title2, weight: .bold)).monospacedDigit().contentTransition(.numericText())
                Text(parts.unit).font(.footnote).foregroundStyle(theme.secondaryText)
            }
            .foregroundStyle(theme.text)
            Sparkline(values: Array(history.suffix(30)), color: color)
                .frame(height: 36)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

struct TintedIconLabelStyle: LabelStyle {
    let color: Color
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 5) {
            configuration.icon.foregroundStyle(color)
            configuration.title
        }
    }
}

private struct NativeStatsCard: View {
    @Environment(SkinStore.self) private var store
    @Environment(\.skinTheme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            row(SkinL("Memory"), SkinFormat.bytes(store.status.memory))
            Divider().padding(.leading, 16)
            NavigationLink {
                ConnectionsPage()
            } label: {
                row(SkinL("Connections"), SkinL("In %lld · Out %lld", store.status.connectionsIn, store.status.connectionsOut), chevron: true)
            }
            .buttonStyle(.plain)
            Divider().padding(.leading, 16)
            row(SkinL("Total Traffic"), "↑ \(SkinFormat.bytes(store.status.uplinkTotal))  ↓ \(SkinFormat.bytes(store.status.downlinkTotal))")
        }
        .background(theme.surface, in: RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous))
    }

    private func row(_ title: String, _ value: String, chevron: Bool = false) -> some View {
        HStack {
            Text(title).foregroundStyle(theme.text)
            Spacer()
            Text(value).foregroundStyle(theme.secondaryText).monospacedDigit()
            if chevron {
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 46)
        .contentShape(Rectangle())
    }
}

private struct NativeCurrentNodeCard: View {
    @Environment(SkinStore.self) private var store
    @Environment(SkinRouter.self) private var router
    @Environment(\.skinTheme) private var theme
    var prominent = false

    var body: some View {
        let group = store.primaryGroup
        let node = store.currentNode
        Button {
            router.showNodes(group: group?.tag)
        } label: {
            if prominent {
                VStack(alignment: .leading, spacing: 8) {
                    Text(SkinL("Current Node · %@", group?.tag ?? "")).font(.footnote.weight(.semibold)).foregroundStyle(theme.secondaryText)
                    Text(node?.tag ?? "—").font(.title2.weight(.bold)).foregroundStyle(theme.text).lineLimit(2)
                    HStack(spacing: 6) {
                        Text(node?.type ?? "").foregroundStyle(theme.secondaryText)
                        LatencyText(delay: node?.delay ?? 0)
                    }
                    .font(.subheadline)
                    Spacer(minLength: 8)
                    Text(skin: "Change Node")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .background(theme.elevatedSurface, in: Capsule())
                        .foregroundStyle(theme.accent)
                }
                .padding(18)
                .frame(maxHeight: .infinity, alignment: .topLeading)
            } else {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(group?.tag ?? SkinL("Node")).font(.footnote).foregroundStyle(theme.secondaryText)
                        Text(node?.tag ?? "—").font(.body).foregroundStyle(theme.text).lineLimit(1)
                    }
                    Spacer()
                    LatencyText(delay: node?.delay ?? 0)
                    Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 60)
            }
        }
        .buttonStyle(.plain)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: prominent ? 20 : theme.cornerRadius, style: .continuous))
        .disabled(group == nil)
    }
}

private struct NativeSystemProxyCard: View {
    @Environment(SkinStore.self) private var store
    @Environment(\.skinTheme) private var theme

    var body: some View {
        Toggle(isOn: Binding(get: { store.systemProxy.enabled }, set: { store.setSystemProxy($0) })) {
            Label {
                Text(skin: "System Proxy")
            } icon: {
                Image(systemName: "network").foregroundStyle(theme.accent)
            }
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 52)
        .frame(maxHeight: .infinity)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct NativeTrafficHero: View {
    @Environment(SkinStore.self) private var store
    @Environment(\.skinTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .lastTextBaseline, spacing: 28) {
                figure(SkinL("Download"), store.status.downlink, theme.download)
                figure(SkinL("Upload"), store.status.uplink, theme.upload)
                Spacer()
                Text(SkinL("Total ↓ %@ · ↑ %@", SkinFormat.bytes(store.status.downlinkTotal), SkinFormat.bytes(store.status.uplinkTotal)))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(theme.secondaryText)
            }
            DualTrafficChart(download: store.downlinkHistory, upload: store.uplinkHistory, downloadColor: theme.download, uploadColor: theme.upload)
                .frame(height: 140)
        }
        .padding(20)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func figure(_ title: String, _ rate: Int64, _ color: Color) -> some View {
        let parts = SkinFormat.rateParts(rate)
        return VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(theme.secondaryText)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(parts.value).font(.system(size: 30, weight: .bold)).monospacedDigit().foregroundStyle(color).contentTransition(.numericText())
                Text(parts.unit).font(.subheadline).foregroundStyle(theme.secondaryText)
            }
        }
    }
}

private struct NativeMetricTile<Extra: View>: View {
    @Environment(\.skinTheme) private var theme
    let title: String
    let value: String?
    let detail: String
    @ViewBuilder var extra: () -> Extra

    init(title: String, value: String?, detail: String, @ViewBuilder extra: @escaping () -> Extra = { EmptyView() }) {
        self.title = title
        self.value = value
        self.detail = detail
        self.extra = extra
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(theme.secondaryText)
            Group {
                if let value { Text(value) } else { extra() }
            }
            .font(.system(size: 26, weight: .bold))
            .monospacedDigit()
            .foregroundStyle(theme.text)
            Text(detail).font(.caption).foregroundStyle(theme.secondaryText)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

/// Primary group as a grid of chips on wide layouts.
private struct NativeGroupStrip: View {
    @Environment(SkinStore.self) private var store
    @Environment(\.skinTheme) private var theme
    let group: SkinOutboundGroup

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(group.tag).font(.headline).foregroundStyle(theme.text)
                Text(verbatim: "\(group.displayType) · \(group.items.count)").font(.caption).foregroundStyle(theme.secondaryText)
                Spacer()
                Button {
                    store.urlTest(group.tag)
                } label: {
                    if store.testingGroups.contains(group.tag) {
                        ProgressView().controlSize(.small)
                    } else {
                        Label(SkinL("Test"), systemImage: "bolt")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 8)], spacing: 8) {
                ForEach(group.items) { item in
                    NodeTile(group: group, item: item)
                }
            }
        }
        .padding(18)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

/// Shown by every skin when no profile exists yet.
struct NoProfileView: View {
    @Environment(\.skinConfiguration) private var configuration
    @Environment(\.skinTheme) private var theme

    var body: some View {
        VStack(spacing: 16) {
            ContentUnavailableView {
                Label(SkinL("No profile yet"), systemImage: "doc.badge.plus")
            } description: {
                Text(skin: "Create a profile or import one from a link, a file or a QR code to get started.")
            }
            if let profiles = configuration.hostPages.profiles {
                NavigationLink {
                    profiles()
                } label: {
                    Text(skin: "New Profile")
                        .font(.headline)
                        .padding(.horizontal, 24)
                        .frame(height: 48)
                }
                .buttonStyle(.glassProminent)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}
