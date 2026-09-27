import SkywaveShared
import SwiftUI

/// C · One Tap. One big button, the current node, the mode. Everything else lives one level
/// deeper under Activity and More. iPad/Mac place the hero next to a live activity panel.
struct FocusSkin: View {
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        Group {
            #if os(macOS)
                FocusRegular()
            #else
                if sizeClass == .regular { FocusRegular() } else { FocusCompact() }
            #endif
        }
        .skinSheets(nodePicker: { group in AnyView(FocusNodePicker(initialGroup: group)) })
    }
}

enum FocusTab: Hashable, CaseIterable {
    case connect, activity, more

    var title: String {
        switch self {
        case .connect: SkinL("Connect")
        case .activity: SkinL("Activity")
        case .more: SkinL("More")
        }
    }

    var symbol: String {
        switch self {
        case .connect: "power"
        case .activity: "waveform.path.ecg"
        case .more: "square.grid.2x2"
        }
    }
}

// MARK: - iPhone

private struct FocusCompact: View {
    @Environment(SkinRouter.self) private var router
    @State private var tab: FocusTab = .connect

    var body: some View {
        SkinTabContainer(selection: $tab, tabs: FocusTab.allCases, barHeight: 84) { tab in
            NavigationStack {
                switch tab {
                case .connect: FocusHome()
                case .activity: FocusActivity()
                case .more: MorePage(title: SkinL("More"))
                }
            }
        } bar: {
            FloatingTabBar(selection: $tab, items: FocusTab.allCases.map { ($0, $0.title, $0.symbol) }, horizontalPadding: 56)
        }
        .onChange(of: router.homeRequests) { _, _ in tab = .connect }
    }
}

/// The hero: power button, state, node, mode.
struct FocusHome: View {
    @Environment(SkinStore.self) private var store
    @Environment(SkinRouter.self) private var router
    @Environment(SkinPreferences.self) private var preferences
    @Environment(\.skinTheme) private var theme
    var showsProfileButton = true

    var body: some View {
        VStack(spacing: 0) {
            if showsProfileButton {
                HStack {
                    FocusProfileButton()
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
            Spacer(minLength: 12)
            if !store.needsGate {
                FocusPowerButton()
                VStack(spacing: 4) {
                    Text(store.phase.label)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(theme.text)
                        .contentTransition(.opacity)
                    if store.isRunning {
                        ElapsedText(since: store.connectedSince)
                            .font(.system(.body, design: .rounded))
                            .foregroundStyle(theme.secondaryText)
                    } else {
                        Text(skin: "Tap to connect")
                            .font(.system(.body, design: .rounded))
                            .foregroundStyle(theme.secondaryText)
                    }
                }
                .padding(.top, 22)
                Spacer(minLength: 20)
                if store.isRunning {
                    VStack(spacing: 12) {
                        FocusNodePill()
                        FocusModePills()
                        Text(verbatim: "↓ \(SkinFormat.rate(store.status.downlink))    ↑ \(SkinFormat.rate(store.status.uplink))")
                            .font(.system(.footnote, design: .rounded).monospacedDigit())
                            .foregroundStyle(theme.secondaryText)
                            .padding(.top, 4)
                    }
                    .padding(.horizontal, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            } else {
                NoProfileView()
            }
            Spacer(minLength: 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.background)
        .animation(.smooth, value: store.isRunning)
        .toolbar(.hidden)
    }
}

struct FocusProfileButton: View {
    @Environment(SkinStore.self) private var store
    @Environment(SkinRouter.self) private var router
    @Environment(\.skinTheme) private var theme

    var body: some View {
        Button {
            router.sheet = .profiles
        } label: {
            HStack(spacing: 6) {
                Text(store.activeProfile?.name ?? SkinL("No Profile")).font(.system(.subheadline, design: .rounded).weight(.semibold))
                Image(systemName: "chevron.down").font(.caption2.weight(.bold))
            }
            .foregroundStyle(theme.text)
            .padding(.horizontal, 14)
            .frame(height: 40)
            .glassEffect(.regular.interactive(), in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!store.hasProfiles)
    }
}

struct FocusPowerButton: View {
    @Environment(SkinStore.self) private var store
    @Environment(\.skinTheme) private var theme
    @Environment(\.skinThumbnailMode) private var thumbnail
    var diameter: CGFloat = 150
    @State private var pulse = false

    var body: some View {
        let active = store.phase.isActive
        ZStack {
            Circle()
                .fill(theme.accent.opacity(active ? 0.10 : 0.05))
                .frame(width: diameter * 1.6, height: diameter * 1.6)
                .scaleEffect(pulse && active ? 1.04 : 1)
            Circle()
                .fill(theme.accent.opacity(active ? 0.14 : 0.07))
                .frame(width: diameter * 1.3, height: diameter * 1.3)
            Button {
                store.toggleService()
            } label: {
                ZStack {
                    if store.phase.isTransitioning {
                        ProgressView().controlSize(.large).tint(active ? theme.onAccent : theme.accent)
                    } else {
                        Image(systemName: "power")
                            .font(.system(size: diameter * 0.36, weight: .medium))
                    }
                }
                .foregroundStyle(active ? theme.onAccent : theme.accent)
                .frame(width: diameter, height: diameter)
                .background(active ? theme.accent : theme.elevatedSurface, in: Circle())
                .shadow(color: theme.accent.opacity(active ? 0.45 : 0.12), radius: 20, y: 12)
                .overlay(Circle().strokeBorder(.white.opacity(0.35), lineWidth: 1))
            }
            .buttonStyle(SkinPressStyle(scale: 0.95))
            .disabled(store.phase == .unavailable || store.phase.isTransitioning)
            .sensoryFeedback(.impact(weight: .medium), trigger: store.phase.isActive)
            .accessibilityLabel(Text(active ? SkinL("Disconnect") : SkinL("Connect")))
        }
        .onAppear {
            guard !thumbnail else { return }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) { pulse = true }
        }
    }
}

struct FocusNodePill: View {
    @Environment(SkinStore.self) private var store
    @Environment(SkinRouter.self) private var router
    @Environment(SkinPreferences.self) private var preferences
    @Environment(\.skinTheme) private var theme

    var body: some View {
        let group = store.primaryGroup
        let node = store.currentNode
        Button {
            router.showNodes(group: group?.tag)
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(group?.tag ?? SkinL("Node")).font(.caption).foregroundStyle(theme.secondaryText)
                    Text(node?.tag ?? "—").font(.system(.title3, design: .rounded).weight(.bold)).foregroundStyle(theme.text).lineLimit(1)
                }
                Spacer()
                Text(preferences.vocabulary.latency(node?.delay ?? 0))
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(theme.accent)
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .background(theme.accent.opacity(0.12), in: Capsule())
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(theme.secondaryText)
            }
            .padding(.horizontal, 18)
            .frame(height: 68)
            .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(group == nil)
    }
}

struct FocusModePills: View {
    @Environment(SkinStore.self) private var store
    @Environment(SkinPreferences.self) private var preferences
    @Environment(\.skinTheme) private var theme

    var body: some View {
        if store.clashModes.count > 1 {
            HStack(spacing: 8) {
                ForEach(store.clashModes, id: \.self) { mode in
                    let selected = mode == store.clashMode
                    Button {
                        store.setClashMode(mode)
                    } label: {
                        Text(preferences.vocabulary.modeShort(mode))
                            .font(.system(.subheadline, design: .rounded).weight(selected ? .semibold : .regular))
                            .foregroundStyle(selected ? theme.onAccent : theme.text)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background {
                                if selected {
                                    Capsule().fill(theme.text)
                                } else {
                                    Capsule().fill(.clear).glassEffect(.regular.interactive(), in: Capsule())
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        }
    }
}

/// Traffic, connections and logs behind one segmented control.
struct FocusActivity: View {
    @Environment(SkinStore.self) private var store
    @Environment(\.skinTheme) private var theme
    @State private var section = 0

    var body: some View {
        VStack(spacing: 0) {
            Picker(SkinL("Section"), selection: $section) {
                Text(skin: "Traffic").tag(0)
                Text(skin: "Connections").tag(1)
                Text(skin: "Logs").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            switch section {
            case 0: FocusTraffic()
            case 1: ConnectionsPage()
            default: LogsPage()
            }
        }
        .background(theme.background)
        .navigationTitle(SkinL("Activity"))
        .navigationBarTitleDisplayModeInline()
    }
}

private struct FocusTraffic: View {
    @Environment(SkinStore.self) private var store
    @Environment(\.skinTheme) private var theme

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(verbatim: SkinFormat.rate(store.status.downlink)).font(.system(size: 34, weight: .bold, design: .rounded)).monospacedDigit().foregroundStyle(theme.text)
                        Spacer()
                        Text(verbatim: "↑ \(SkinFormat.rate(store.status.uplink))").font(.system(.subheadline, design: .rounded)).foregroundStyle(theme.secondaryText)
                    }
                    DualTrafficChart(download: store.downlinkHistory, upload: store.uplinkHistory, downloadColor: theme.download, uploadColor: theme.upload)
                        .frame(height: 160)
                }
                .skinCard(theme, padding: 18)
                HStack(spacing: 12) {
                    stat(SkinL("Received"), SkinFormat.bytes(store.status.downlinkTotal))
                    stat(SkinL("Sent"), SkinFormat.bytes(store.status.uplinkTotal))
                }
                HStack(spacing: 12) {
                    stat(SkinL("Connections"), "\(store.status.totalConnections)")
                    stat(SkinL("Memory"), SkinFormat.bytes(store.status.memory))
                }
            }
            .padding(16)
        }
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(theme.secondaryText)
            Text(value).font(.system(.title3, design: .rounded).weight(.bold)).monospacedDigit().foregroundStyle(theme.text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .skinCard(theme, padding: 16)
    }
}

// MARK: - Node picker sheet

struct FocusNodePicker: View {
    @Environment(SkinStore.self) private var store
    @Environment(SkinPreferences.self) private var preferences
    @Environment(\.skinTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    var initialGroup: String?
    @State private var groupTag: String?
    @State private var search = ""

    var body: some View {
        let selectable = store.groups.filter(\.selectable)
        let group = store.group(groupTag ?? initialGroup ?? "") ?? store.primaryGroup
        NavigationStack {
            List {
                if selectable.count > 1 {
                    Picker(SkinL("Group"), selection: Binding(get: { group?.tag ?? "" }, set: { groupTag = $0 })) {
                        ForEach(selectable) { Text($0.tag).tag($0.tag) }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
                if let group {
                    Section {
                        ForEach(group.items.filter { search.isEmpty || $0.tag.localizedCaseInsensitiveContains(search) }) { item in
                            let selected = item.tag == group.selected
                            Button {
                                store.select(item.tag, in: group.tag)
                                dismiss()
                            } label: {
                                HStack(spacing: 12) {
                                    Text(item.tag).font(.system(.body, design: .rounded).weight(selected ? .bold : .regular)).foregroundStyle(theme.text)
                                    Spacer()
                                    Text(item.type).font(.caption).foregroundStyle(theme.secondaryText)
                                    Text(preferences.vocabulary.latency(item.delay))
                                        .font(.system(.footnote, design: .rounded).weight(.semibold))
                                        .foregroundStyle(item.grade.color)
                                        .frame(minWidth: 64)
                                        .frame(height: 26)
                                        .background(item.grade.color.opacity(0.12), in: Capsule())
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(selected ? theme.accent.opacity(0.08) : theme.elevatedSurface)
                            .accessibilityAddTraits(selected ? .isSelected : [])
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(theme.background)
            .searchable(text: $search, prompt: Text(skin: "Search nodes"))
            .navigationTitle(SkinL("Choose a Node"))
            .navigationBarTitleDisplayModeInline()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(SkinL("Done")) { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        if let group { store.urlTest(group.tag) }
                    } label: {
                        if let group, store.testingGroups.contains(group.tag) {
                            ProgressView()
                        } else {
                            Label(SkinL("Test"), systemImage: "bolt")
                        }
                    }
                }
            }
        }
    }
}

// MARK: - iPad / Mac

private struct FocusRegular: View {
    @Environment(SkinStore.self) private var store
    @Environment(SkinRouter.self) private var router
    @Environment(\.skinTheme) private var theme

    var body: some View {
        HStack(spacing: 0) {
            FocusHome(showsProfileButton: true)
                .frame(width: 440)
            Divider().overlay(theme.separator)
            NavigationStack {
                FocusActivity()
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            Button {
                                router.sheet = .more
                            } label: {
                                Label(SkinL("More"), systemImage: "square.grid.2x2")
                            }
                        }
                    }
            }
        }
        .background(theme.background)
    }
}

extension View {
    /// Inline navigation title on iOS; no-op on macOS.
    func navigationBarTitleDisplayModeInline() -> some View {
        #if os(iOS)
            navigationBarTitleDisplayMode(.inline)
        #else
            self
        #endif
    }
}
