import SBSkinShared
import SwiftUI

/// B · Instrument. Dark cockpit: huge monospaced numbers, a live dual chart, node tiles with
/// latency meters. iPad/Mac get an icon rail, a live connection table and an inspector.
struct InstrumentSkin: View {
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        Group {
            #if os(macOS)
                InstrumentRegular()
            #else
                if sizeClass == .regular { InstrumentRegular() } else { InstrumentCompact() }
            #endif
        }
        .skinSheets(nodePicker: { group in
            AnyView(NavigationStack { InstrumentNodesPage(initialGroup: group).instrumentDoneButton() })
        })
    }
}

enum InstrumentTab: Hashable, CaseIterable {
    case home, groups, connections, logs, more

    var title: String {
        switch self {
        case .home: SkinL("Dashboard")
        case .groups: SkinL("Groups")
        case .connections: SkinL("Connections")
        case .logs: SkinL("Logs")
        case .more: SkinL("Settings")
        }
    }

    var symbol: String {
        switch self {
        case .home: "gauge.with.dots.needle.67percent"
        case .groups: "square.grid.2x2"
        case .connections: "arrow.left.arrow.right"
        case .logs: "list.bullet.rectangle"
        case .more: "gearshape"
        }
    }
}

private extension View {
    func instrumentDoneButton() -> some View {
        modifier(DoneButtonModifier())
    }
}

private struct DoneButtonModifier: ViewModifier {
    @Environment(\.dismiss) private var dismiss
    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(SkinL("Done")) { dismiss() }
            }
        }
    }
}

// MARK: - iPhone

private struct InstrumentCompact: View {
    @Environment(SkinRouter.self) private var router
    @Environment(\.skinTheme) private var theme
    @State private var tab: InstrumentTab = .home

    var body: some View {
        SkinTabContainer(selection: $tab, tabs: InstrumentTab.allCases, barHeight: 76) { tab in
            NavigationStack {
                switch tab {
                case .home: InstrumentHome()
                case .groups: InstrumentNodesPage()
                case .connections: ConnectionsPage()
                case .logs: LogsPage()
                case .more: MorePage()
                }
            }
        } bar: {
            FloatingTabBar(
                selection: $tab,
                items: InstrumentTab.allCases.map { ($0, $0.title, $0.symbol) },
                showsTitles: false,
                selectedTint: theme.accent,
                selectedBackground: theme.accent.opacity(0.18),
                foreground: theme.secondaryText,
                horizontalPadding: 44
            )
        }
        .onChange(of: router.homeRequests) { _, _ in tab = .home }
    }
}

/// Phone dashboard.
struct InstrumentHome: View {
    @Environment(SkinStore.self) private var store
    @Environment(SkinRouter.self) private var router
    @Environment(SkinPreferences.self) private var preferences
    @Environment(\.skinTheme) private var theme
    @Environment(\.skinConfiguration) private var configuration

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                if store.needsGate {
                    NoProfileView()
                } else if store.isRunning {
                    hero
                    DualTrafficChart(
                        download: store.downlinkHistory,
                        upload: store.uplinkHistory,
                        downloadColor: theme.download,
                        uploadColor: theme.upload,
                        gridColor: Color.white.opacity(0.06)
                    )
                    .frame(height: 150)
                    .padding(.horizontal, -16)
                    InstrumentModeButtons()
                    InstrumentStatsGrid()
                    InstrumentNodeStrip()
                } else {
                    InstrumentIdle()
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .scrollIndicators(.hidden)
        .background(theme.background)
        .toolbar(.hidden)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Button {
                router.sheet = .profiles
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(configuration.appName.uppercased())
                        .font(.caption.weight(.semibold))
                        .tracking(3)
                        .foregroundStyle(theme.secondaryText)
                    HStack(spacing: 4) {
                        Text(store.activeProfile?.name ?? SkinL("No Profile"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(theme.text)
                        Image(systemName: "chevron.down").font(.caption2.weight(.bold)).foregroundStyle(theme.secondaryText)
                    }
                }
            }
            .buttonStyle(.plain)
            Spacer()
            if store.isRunning {
                HStack(spacing: 6) {
                    Circle().fill(theme.accent).frame(width: 7, height: 7)
                    ElapsedText(since: store.connectedSince)
                }
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(theme.accent)
                .padding(.horizontal, 12)
                .frame(height: 30)
                .background(theme.accent.opacity(0.12), in: Capsule())
            }
            InstrumentPowerButton(size: 44)
        }
        .padding(.top, 8)
    }

    private var hero: some View {
        let down = SkinFormat.rateParts(store.status.downlink)
        return VStack(alignment: .leading, spacing: 2) {
            Text(skin: "Download").font(.footnote.weight(.semibold)).foregroundStyle(theme.secondaryText)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(down.value)
                    .font(.system(size: 64, weight: .semibold, design: .monospaced))
                    .tracking(-2)
                    .foregroundStyle(theme.download)
                    .contentTransition(.numericText())
                Text(down.unit).font(.system(.body, design: .monospaced)).foregroundStyle(theme.secondaryText)
            }
            HStack(spacing: 16) {
                (Text(skin: "Upload") + Text(verbatim: " ") + Text(verbatim: SkinFormat.rate(store.status.uplink)).foregroundColor(theme.upload))
                Text(SkinL("Total ↓ %@ ↑ %@", SkinFormat.bytes(store.status.downlinkTotal), SkinFormat.bytes(store.status.uplinkTotal)))
            }
            .font(.system(size: 13, design: .monospaced))
            .foregroundStyle(theme.secondaryText)
        }
        .accessibilityElement(children: .combine)
    }
}

struct InstrumentPowerButton: View {
    @Environment(SkinStore.self) private var store
    @Environment(\.skinTheme) private var theme
    var size: CGFloat = 44

    var body: some View {
        Button {
            store.toggleService()
        } label: {
            Group {
                if store.phase.isTransitioning {
                    ProgressView().tint(theme.accent)
                } else {
                    Image(systemName: "power").font(.system(size: size * 0.42, weight: .bold))
                }
            }
            .foregroundStyle(store.phase.isActive ? theme.accent : theme.secondaryText)
            .frame(width: size, height: size)
            .glassEffect(.regular.tint(store.phase.isActive ? theme.accent.opacity(0.25) : nil).interactive(), in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(store.phase == .unavailable || store.phase.isTransitioning)
        .accessibilityLabel(Text(store.phase.isActive ? SkinL("Stop") : SkinL("Start")))
    }
}

struct InstrumentModeButtons: View {
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
                            .font(.subheadline.weight(selected ? .semibold : .regular))
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .foregroundStyle(selected ? theme.accent : theme.text.opacity(0.8))
                            .background(selected ? theme.accent.opacity(0.12) : theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(selected ? theme.accent : theme.separator, lineWidth: 1))
                    }
                    .buttonStyle(SkinPressStyle())
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        }
    }
}

struct InstrumentStatsGrid: View {
    @Environment(SkinStore.self) private var store
    @Environment(\.skinTheme) private var theme
    var columns = 2

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: columns), spacing: 10) {
            tile(SkinL("Memory"), SkinFormat.bytes(store.status.memory), fraction: Double(store.status.memory) / 256_000_000, color: theme.download)
            tile(SkinL("Goroutines"), "\(store.status.goroutines)", fraction: Double(store.status.goroutines) / 1000, color: theme.download)
            NavigationLink {
                ConnectionsPage()
            } label: {
                tile(SkinL("Connections in/out"), "\(store.status.connectionsIn) / \(store.status.connectionsOut)", fraction: Double(store.status.totalConnections) / 300, color: theme.upload)
            }
            .buttonStyle(.plain)
            tile(SkinL("Session traffic"), SkinFormat.bytes(store.status.totalTraffic), fraction: nil, color: theme.upload, history: store.downlinkHistory)
        }
    }

    private func tile(_ title: String, _ value: String, fraction: Double?, color: Color, history: [Double]? = nil) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(theme.secondaryText)
            Text(value).font(.system(size: 22, weight: .semibold, design: .monospaced)).foregroundStyle(theme.text).lineLimit(1).minimumScaleFactor(0.6)
            if let fraction {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.08))
                        Capsule().fill(color).frame(width: max(4, proxy.size.width * min(fraction, 1)))
                    }
                }
                .frame(height: 4)
            } else if let history {
                Sparkline(values: Array(history.suffix(24)), color: color, lineWidth: 1.5, fill: false).frame(height: 14)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(theme.separator))
        .accessibilityElement(children: .combine)
    }
}

private struct InstrumentNodeStrip: View {
    @Environment(SkinStore.self) private var store
    @Environment(SkinRouter.self) private var router
    @Environment(\.skinTheme) private var theme

    var body: some View {
        if let group = store.primaryGroup {
            let node = store.currentNode
            Button {
                router.showNodes(group: group.tag)
            } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(group.tag).font(.caption).foregroundStyle(theme.secondaryText)
                        Text(node?.tag ?? "—").font(.headline).foregroundStyle(theme.text).lineLimit(1)
                    }
                    Spacer()
                    SignalBars(grade: node?.grade ?? .untested, activeColor: theme.accent, inactiveColor: .white.opacity(0.15))
                    LatencyText(delay: node?.delay ?? 0, font: .system(.subheadline, design: .monospaced).weight(.semibold))
                }
                .padding(.horizontal, 14)
                .frame(height: 58)
                .background(theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(theme.separator))
            }
            .buttonStyle(SkinPressStyle(scale: 0.99))
        }
    }
}

private struct InstrumentIdle: View {
    @Environment(SkinStore.self) private var store
    @Environment(\.skinTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(verbatim: "0.0")
                .font(.system(size: 64, weight: .semibold, design: .monospaced))
                .foregroundStyle(theme.secondaryText.opacity(0.4))
            Text(store.phase.label)
                .font(.system(.title3, design: .monospaced).weight(.semibold))
                .foregroundStyle(theme.text)
            Text(skin: "Tap the power button to start the service.")
                .font(.subheadline)
                .foregroundStyle(theme.secondaryText)
            Button {
                store.startService()
            } label: {
                Label(SkinL("Start"), systemImage: "power")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
            }
            .buttonStyle(.glassProminent)
            .tint(theme.accent)
            .disabled(store.phase != .stopped)
        }
        .padding(.top, 40)
    }
}

/// Group chips + two-column node tiles with latency meters.
struct InstrumentNodesPage: View {
    @Environment(SkinStore.self) private var store
    @Environment(\.skinTheme) private var theme
    @Environment(\.horizontalSizeClass) private var sizeClass
    var initialGroup: String?
    @State private var selectedGroup: String?

    var body: some View {
        let group = store.group(selectedGroup ?? initialGroup ?? "") ?? store.primaryGroup
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(store.groups) { item in
                            let selected = item.tag == group?.tag
                            Button {
                                selectedGroup = item.tag
                            } label: {
                                Text(item.tag)
                                    .font(.subheadline.weight(.semibold))
                                    .padding(.horizontal, 14)
                                    .frame(height: 34)
                                    .foregroundStyle(selected ? theme.accent : theme.text.opacity(0.8))
                                    .background(selected ? theme.accent.opacity(0.14) : theme.surface, in: Capsule())
                                    .overlay(Capsule().strokeBorder(selected ? theme.accent : theme.separator))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .scrollIndicators(.hidden)
                if let group {
                    HStack {
                        Text(verbatim: "\(group.displayType.uppercased()) · \(group.items.count)")
                        Spacer()
                        Text(SkinL("Now %@", store.resolvedNode(in: group).node?.tag ?? group.selected)).lineLimit(1)
                    }
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(theme.secondaryText)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: sizeClass == .regular ? 200 : 150), spacing: 10)], spacing: 10) {
                        ForEach(group.items) { item in
                            InstrumentNodeTile(group: group, item: item)
                        }
                    }
                } else {
                    ContentUnavailableView(SkinL("No outbound groups"), systemImage: "square.grid.2x2")
                }
            }
            .padding(16)
        }
        .background(theme.background)
        .navigationTitle(SkinL("Groups"))
        .toolbar {
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

private struct InstrumentNodeTile: View {
    @Environment(SkinStore.self) private var store
    @Environment(\.skinTheme) private var theme
    let group: SkinOutboundGroup
    let item: SkinOutbound

    var body: some View {
        let selected = item.tag == group.selected
        let grade = item.grade
        let color: Color = switch grade {
        case .excellent, .good: theme.accent
        case .fair: theme.upload
        case .poor, .unreachable: SkinPalette.bad
        case .untested: theme.secondaryText
        }
        Button {
            store.select(item.tag, in: group.tag)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(item.tag).font(.subheadline.weight(.semibold)).foregroundStyle(theme.text).lineLimit(1)
                    Spacer(minLength: 4)
                    Text(item.type.uppercased()).font(.system(size: 9, weight: .semibold, design: .monospaced)).foregroundStyle(theme.secondaryText).lineLimit(1)
                }
                Text(delayText)
                    .font(.system(size: 24, weight: .semibold, design: .monospaced))
                    .foregroundStyle(color)
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.08))
                        Capsule().fill(color).frame(width: proxy.size.width * meter)
                    }
                }
                .frame(height: 3)
            }
            .padding(12)
            .background(selected ? theme.accent.opacity(0.1) : theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(selected ? theme.accent : theme.separator, lineWidth: selected ? 1.5 : 1))
        }
        .buttonStyle(SkinPressStyle())
        .disabled(!group.selectable)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var delayText: String {
        switch item.grade {
        case .untested: "— —"
        case .unreachable: SkinL("TIMEOUT")
        default: "\(item.delay)ms"
        }
    }

    private var meter: CGFloat {
        guard item.delay > 0, item.delay != .max else { return 0 }
        return max(0.06, 1 - CGFloat(item.delay) / 1600)
    }
}
