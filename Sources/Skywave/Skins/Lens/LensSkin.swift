import SkywaveShared
import SwiftUI

/// E · Transparent. Like Screen Time for your traffic: where it went, which rule sent it
/// there, and the full journey of any single connection.
struct LensSkin: View {
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        Group {
            #if os(macOS)
                LensRegular()
            #else
                if sizeClass == .regular { LensRegular() } else { LensCompact() }
            #endif
        }
        .skinSheets()
    }
}

enum LensTab: Hashable, CaseIterable {
    case today, routes, records, more

    var title: String {
        switch self {
        case .today: SkinL("Today")
        case .routes: SkinL("Routes")
        case .records: SkinL("Records")
        case .more: SkinL("More")
        }
    }

    var symbol: String {
        switch self {
        case .today: "waveform.path.ecg"
        case .routes: "point.topleft.down.to.point.bottomright.curvepath"
        case .records: "list.bullet.rectangle"
        case .more: "ellipsis"
        }
    }
}

// MARK: - iPhone

private struct LensCompact: View {
    @Environment(SkinRouter.self) private var router
    @State private var tab: LensTab = .today

    var body: some View {
        SkinTabContainer(selection: $tab, tabs: LensTab.allCases, barHeight: 80) { tab in
            NavigationStack {
                switch tab {
                case .today: LensToday()
                case .routes: NodesPage().navigationTitle(SkinL("Routes"))
                case .records: LogsPage().navigationTitle(SkinL("Records"))
                case .more: MorePage(title: SkinL("More"))
                }
            }
        } bar: {
            FloatingTabBar(selection: $tab, items: LensTab.allCases.map { ($0, $0.title, $0.symbol) })
        }
        .onChange(of: router.homeRequests) { _, _ in tab = .today }
    }
}

/// “Today”: split of proxied vs direct bytes, what's happening now, and per-exit totals.
struct LensToday: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(SkinStore.self) private var store
    @Environment(SkinRouter.self) private var router
    @Environment(SkinPreferences.self) private var preferences
    @Environment(\.skinTheme) private var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if store.needsGate {
                    NoProfileView()
                } else if store.isRunning {
                    LensSplitCard()
                    LensHappeningCard()
                    LensModeCard()
                    LensExitsCard()
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(store.phase.label).font(.title2.weight(.bold)).foregroundStyle(theme.text)
                        Text(skin: "Turn protection on to see where your traffic goes.").foregroundStyle(theme.secondaryText)
                        Button {
                            store.startService()
                        } label: {
                            Text(skin: "Turn On").font(.headline).frame(maxWidth: .infinity).frame(height: 50)
                        }
                        .buttonStyle(.glassProminent)
                        .disabled(store.phase != .stopped)
                    }
                    .skinCard(theme, padding: 20)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(theme.background)
        .navigationTitle(SkinL("Today"))
        .toolbar {
            if sizeClass != .regular {
                ToolbarItem(placement: .primaryAction) {
                    LensPowerPill()
                }
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack(spacing: 4) {
                if store.isRunning {
                    Text(skin: "On for")
                    ElapsedText(since: store.connectedSince)
                    Text(verbatim: "·")
                }
                Text(store.activeProfile?.name ?? "")
            }
            .font(.subheadline)
            .foregroundStyle(theme.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.bottom, 6)
        }
        .subscribesToConnections(store)
    }
}

struct LensPowerPill: View {
    @Environment(SkinStore.self) private var store
    @Environment(\.skinTheme) private var theme

    var body: some View {
        Toggle(isOn: Binding(get: { store.phase.isActive }, set: { _ in store.toggleService() })) {
            Text(store.phase.isActive ? SkinL("Protected") : SkinL("Off")).font(.subheadline.weight(.semibold))
        }
        .toggleStyle(.switch)
        .tint(theme.accent)
        .fixedSize()
        .disabled(store.phase == .unavailable || store.phase.isTransitioning)
    }
}

private struct LensSplitCard: View {
    @Environment(SkinStore.self) private var store
    @Environment(\.skinTheme) private var theme

    var body: some View {
        let split = store.routeSplit
        let total = max(split.proxied + split.direct, 1)
        let fraction = CGFloat(split.proxied) / CGFloat(total)
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(skin: "Where traffic went").font(.footnote.weight(.bold)).foregroundStyle(theme.secondaryText)
                Spacer()
                Text(SkinFormat.bytes(split.proxied + split.direct)).font(.system(size: 26, weight: .heavy)).monospacedDigit().foregroundStyle(theme.text)
            }
            GeometryReader { proxy in
                HStack(spacing: 3) {
                    RoundedRectangle(cornerRadius: 7).fill(theme.accent).frame(width: max(8, (proxy.size.width - 3) * fraction))
                    RoundedRectangle(cornerRadius: 7).fill(LensPalette.direct)
                }
            }
            .frame(height: 14)
            .animation(.smooth, value: fraction)
            HStack(spacing: 18) {
                legend(SkinL("Via proxy"), SkinFormat.bytes(split.proxied), theme.accent)
                legend(SkinL("Direct"), SkinFormat.bytes(split.direct), LensPalette.direct)
            }
            Text(skin: "Counted from connections seen since the service started.")
                .font(.caption2)
                .foregroundStyle(theme.secondaryText)
        }
        .skinCard(theme, padding: 18)
    }

    private func legend(_ title: String, _ value: String, _ color: Color) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 10, height: 10)
            Text(title).foregroundStyle(theme.text)
            Text(value).fontWeight(.bold).monospacedDigit().foregroundStyle(theme.text)
        }
        .font(.footnote)
    }
}

enum LensPalette {
    static let direct = Color(light: Color(hex: 0x86D9C6), dark: Color(hex: 0x3FA58F))
    static let directText = Color(light: Color(hex: 0x146B5A), dark: Color(hex: 0x7FDCC6))
}

private struct LensHappeningCard: View {
    @Environment(SkinStore.self) private var store
    @Environment(\.skinTheme) private var theme

    var body: some View {
        let rows = store.activeConnections.sorted { $0.createdAt > $1.createdAt }.prefix(5)
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(skin: "Happening now").font(.footnote.weight(.bold)).foregroundStyle(theme.secondaryText)
                Spacer()
                NavigationLink {
                    ConnectionsPage()
                } label: {
                    Text(SkinL("All %lld ›", store.activeConnections.count)).font(.footnote.weight(.semibold)).foregroundStyle(theme.accent)
                }
            }
            .padding(.bottom, 4)
            if rows.isEmpty {
                Text(skin: "Nothing yet").foregroundStyle(theme.secondaryText).frame(minHeight: 44)
            }
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, connection in
                NavigationLink {
                    ConnectionDetailPage(connectionID: connection.id)
                } label: {
                    LensConnectionRow(connection: connection)
                }
                .buttonStyle(.plain)
                if index < rows.count - 1 {
                    Divider().overlay(theme.separator).padding(.leading, 48)
                }
            }
        }
        .skinCard(theme, padding: 16)
    }
}

struct LensConnectionRow: View {
    @Environment(\.skinTheme) private var theme
    let connection: SkinConnection

    var body: some View {
        HStack(spacing: 12) {
            Text(verbatim: String(connection.hostName.first.map(String.init) ?? "?").uppercased())
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(connection.isDirect ? LensPalette.directText : .white)
                .frame(width: 36, height: 36)
                .background(connection.isDirect ? LensPalette.direct.opacity(0.35) : theme.accent, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(connection.hostName).font(.subheadline.weight(.semibold)).foregroundStyle(theme.text).lineLimit(1)
                HStack(spacing: 4) {
                    Text(ruleSummary)
                    Text(verbatim: "·")
                    Text(verbatim: SkinFormat.duration(Date().timeIntervalSince(connection.createdAt)))
                }
                .font(.caption)
                .foregroundStyle(theme.secondaryText)
                .lineLimit(1)
            }
            Spacer(minLength: 6)
            Text(connection.isDirect ? SkinL("Direct") : connection.outbound)
                .font(.caption.weight(.bold))
                .lineLimit(1)
                .padding(.horizontal, 10)
                .frame(height: 26)
                .foregroundStyle(connection.isDirect ? LensPalette.directText : theme.accent)
                .background((connection.isDirect ? LensPalette.direct : theme.accent).opacity(0.14), in: Capsule())
        }
        .frame(minHeight: 54)
        .contentShape(Rectangle())
    }

    private var ruleSummary: String {
        let summary = connection.ruleSummary
        return summary.isEmpty ? SkinL("Default route") : SkinL("Matched %@", summary)
    }
}

private struct LensModeCard: View {
    @Environment(SkinStore.self) private var store
    @Environment(SkinPreferences.self) private var preferences
    @Environment(\.skinTheme) private var theme

    var body: some View {
        if store.clashModes.count > 1 {
            Menu {
                Picker(SkinL("Mode"), selection: Binding(get: { store.clashMode }, set: { store.setClashMode($0) })) {
                    ForEach(store.clashModes, id: \.self) { Text(preferences.vocabulary.mode($0)).tag($0) }
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(skin: "Routing").font(.footnote.weight(.bold)).foregroundStyle(theme.secondaryText)
                        Text(preferences.vocabulary.mode(store.clashMode)).font(.headline).foregroundStyle(theme.text)
                        Text(explanation).font(.caption).foregroundStyle(theme.secondaryText).multilineTextAlignment(.leading)
                    }
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down").font(.footnote.weight(.semibold)).foregroundStyle(theme.secondaryText)
                }
                .skinCard(theme, padding: 18)
            }
            .buttonStyle(.plain)
        }
    }

    private var explanation: String {
        switch store.clashMode.lowercased() {
        case "rule": SkinL("Rules decide, connection by connection.")
        case "global": SkinL("Everything goes through the proxy.")
        case "direct": SkinL("Nothing goes through the proxy.")
        default: SkinL("Custom mode from your profile.")
        }
    }
}

/// Bytes per exit (final outbound), top five.
private struct LensExitsCard: View {
    @Environment(SkinStore.self) private var store
    @Environment(\.skinTheme) private var theme

    var body: some View {
        let buckets = Dictionary(grouping: store.connections) { $0.isDirect ? SkinL("Direct") : $0.outbound }
            .map { (name: $0.key, bytes: $0.value.reduce(Int64(0)) { $0 + $1.totalBytes }, count: $0.value.count, direct: $0.value.first?.isDirect ?? false) }
            .sorted { $0.bytes > $1.bytes }
            .prefix(5)
        let top = max(buckets.first?.bytes ?? 1, 1)
        if !buckets.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text(skin: "By exit").font(.footnote.weight(.bold)).foregroundStyle(theme.secondaryText)
                ForEach(Array(buckets), id: \.name) { bucket in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(bucket.name).font(.subheadline.weight(.semibold)).foregroundStyle(theme.text).lineLimit(1)
                            Spacer()
                            Text(SkinL("%@ · %lld conns", SkinFormat.bytes(bucket.bytes), bucket.count)).font(.caption.monospacedDigit()).foregroundStyle(theme.secondaryText)
                        }
                        GeometryReader { proxy in
                            Capsule().fill(bucket.direct ? LensPalette.direct : theme.accent)
                                .frame(width: max(6, proxy.size.width * CGFloat(bucket.bytes) / CGFloat(top)))
                        }
                        .frame(height: 6)
                    }
                }
            }
            .skinCard(theme, padding: 18)
        }
    }
}

// MARK: - iPad / Mac

enum LensSection: Hashable {
    case today, byRule, byExit, byApp, routes, records, more

    var title: String {
        switch self {
        case .today: SkinL("Today")
        case .byRule: SkinL("By Rule")
        case .byExit: SkinL("By Exit")
        case .byApp: SkinL("By App")
        case .routes: SkinL("Routes")
        case .records: SkinL("Records")
        case .more: SkinL("Settings")
        }
    }

    var symbol: String {
        switch self {
        case .today: "waveform.path.ecg"
        case .byRule: "line.3.horizontal.decrease"
        case .byExit: "arrow.up.right.square"
        case .byApp: "app.badge"
        case .routes: "point.topleft.down.to.point.bottomright.curvepath"
        case .records: "list.bullet.rectangle"
        case .more: "gearshape"
        }
    }
}

private struct LensRegular: View {
    @Environment(SkinStore.self) private var store
    @Environment(SkinRouter.self) private var router
    @Environment(\.skinTheme) private var theme
    @State private var section: LensSection? = .today
    @State private var selectedConnection: String?

    private var sections: [LensSection] {
        var list: [LensSection] = [.today, .byRule, .byExit]
        if store.connections.contains(where: { $0.processName != nil }) { list.append(.byApp) }
        return list
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $section) {
                Section(SkinL("Activity")) {
                    ForEach(sections, id: \.self) { item in
                        Label(item.title, systemImage: item.symbol).tag(item)
                    }
                }
                Section(SkinL("Setup")) {
                    ForEach([LensSection.routes, .records, .more], id: \.self) { item in
                        Label(item.title, systemImage: item.symbol).tag(item)
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 190, ideal: 220)
        } detail: {
            NavigationStack {
                Group {
                    switch section ?? .today {
                    case .today:
                        HStack(spacing: 0) {
                            LensToday().frame(minWidth: 380, idealWidth: 460)
                            Divider()
                            LensJourneyPanel(connectionID: store.activeConnections.max(by: { $0.createdAt < $1.createdAt })?.id)
                        }
                    case .byRule: LensGroupedBrowser(dimension: .rule, selection: $selectedConnection)
                    case .byExit: LensGroupedBrowser(dimension: .exit, selection: $selectedConnection)
                    case .byApp: LensGroupedBrowser(dimension: .app, selection: $selectedConnection)
                    case .routes: NodesPage().navigationTitle(SkinL("Routes"))
                    case .records: LogsPage().navigationTitle(SkinL("Records"))
                    case .more: MorePage()
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .primaryAction) { LensPowerPill() }
                }
            }
        }
        .onChange(of: router.homeRequests) { _, _ in section = .today }
    }
}

/// Connections grouped by a dimension, with the journey of the selection beside them.
private struct LensGroupedBrowser: View {
    enum Dimension { case rule, exit, app }

    @Environment(SkinStore.self) private var store
    @Environment(\.skinTheme) private var theme
    let dimension: Dimension
    @Binding var selection: String?

    var body: some View {
        let groups = Dictionary(grouping: store.connections, by: key)
            .map { (key: $0.key, items: $0.value.sorted { $0.createdAt > $1.createdAt }) }
            .sorted { $0.items.reduce(0) { $0 + $1.totalBytes } > $1.items.reduce(0) { $0 + $1.totalBytes } }
        HStack(spacing: 0) {
            List(selection: $selection) {
                ForEach(groups, id: \.key) { group in
                    Section {
                        ForEach(group.items.prefix(30)) { connection in
                            LensConnectionRow(connection: connection).tag(connection.id)
                        }
                    } header: {
                        HStack {
                            Text(group.key).lineLimit(1)
                            Spacer()
                            Text(SkinFormat.bytes(group.items.reduce(0) { $0 + $1.totalBytes })).monospacedDigit()
                        }
                    }
                }
            }
            .frame(minWidth: 380, idealWidth: 440)
            Divider()
            LensJourneyPanel(connectionID: selection ?? groups.first?.items.first?.id)
        }
        .navigationTitle(title)
        .subscribesToConnections(store)
    }

    private var title: String {
        switch dimension {
        case .rule: SkinL("By Rule")
        case .exit: SkinL("By Exit")
        case .app: SkinL("By App")
        }
    }

    private func key(_ connection: SkinConnection) -> String {
        switch dimension {
        case .rule: connection.rule.components(separatedBy: "=>").first?.trimmingCharacters(in: .whitespaces).nonEmpty ?? SkinL("Default route")
        case .exit: connection.isDirect ? SkinL("Direct") : connection.outbound
        case .app: connection.processName ?? SkinL("Unknown app")
        }
    }
}

private struct LensJourneyPanel: View {
    @Environment(SkinStore.self) private var store
    @Environment(\.skinTheme) private var theme
    let connectionID: String?

    var body: some View {
        Group {
            if let connectionID, let connection = store.connections.first(where: { $0.id == connectionID }) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(connection.hostName).font(.title.weight(.heavy)).foregroundStyle(theme.text).lineLimit(2)
                                Text(connection.processName ?? connection.inbound).font(.subheadline).foregroundStyle(theme.secondaryText)
                            }
                            Spacer()
                            if connection.isActive {
                                Button(SkinL("Disconnect"), role: .destructive) { store.close(connection) }
                                    .buttonStyle(.bordered)
                            }
                        }
                        JourneyView(connection: connection).skinCard(theme, padding: 18)
                        TrafficSummary(connection: connection)
                        MetadataList(connection: connection)
                    }
                    .padding(22)
                }
            } else {
                ContentUnavailableView(SkinL("Pick a connection"), systemImage: "point.topleft.down.to.point.bottomright.curvepath", description: Text(skin: "See exactly how it got to its destination."))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.background)
    }
}

extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
