import SBSkinShared
import SwiftUI

/// I · Bento. A grid of modules you arrange yourself; dot-matrix numerals, black, white, one red.
struct BentoSkin: View {
    @Environment(\.horizontalSizeClass) private var sizeClass


    var body: some View {
        Group {
            #if os(macOS)
                BentoRegular()
            #else
                if sizeClass == .regular { BentoRegular() } else { BentoCompact() }
            #endif
        }
        .skinSheets()
    }
}

enum BentoTab: Hashable, CaseIterable {
    case home, groups, logs, settings

    var title: String {
        switch self {
        case .home: SkinL("Home")
        case .groups: SkinL("Groups")
        case .logs: SkinL("Logs")
        case .settings: SkinL("Settings")
        }
    }

    var symbol: String {
        switch self {
        case .home: "square.grid.2x2.fill"
        case .groups: "point.3.connected.trianglepath.dotted"
        case .logs: "list.bullet.rectangle"
        case .settings: "gearshape"
        }
    }
}

// MARK: - iPhone

private struct BentoCompact: View {
    @Environment(SkinRouter.self) private var router
    @Environment(\.skinTheme) private var theme
    @State private var tab: BentoTab = .home

    var body: some View {
        SkinTabContainer(selection: $tab, tabs: BentoTab.allCases, barHeight: 78) { tab in
            NavigationStack {
                switch tab {
                case .home: BentoHome(columns: 2)
                case .groups: NodesPage()
                case .logs: LogsPage()
                case .settings: MorePage()
                }
            }
        } bar: {
            HStack(spacing: 4) {
                ForEach(BentoTab.allCases, id: \.self) { item in
                    Button {
                        tab = item
                    } label: {
                        Image(systemName: item.symbol)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 50, height: 44)
                            .background(item == tab ? theme.accent : .clear, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(item.title))
                    .accessibilityAddTraits(item == tab ? .isSelected : [])
                }
            }
            .padding(6)
            .background(Color(hex: 0x0F0F0F).opacity(0.92), in: Capsule())
            .glassEffect(.regular.tint(.black.opacity(0.5)), in: Capsule())
            .padding(.bottom, 10)
        }
        .onChange(of: router.homeRequests) { _, _ in tab = .home }
    }
}

// MARK: - iPad / Mac

private struct BentoRegular: View {
    @Environment(SkinRouter.self) private var router
    @Environment(\.skinTheme) private var theme
    @Environment(\.skinConfiguration) private var configuration
    @State private var tab: BentoTab = .home

    var body: some View {
        NavigationStack {
            Group {
                switch tab {
                case .home: BentoHome(columns: 6)
                case .groups: NodesPage()
                case .logs: LogsPage()
                case .settings: MorePage()
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker(SkinL("Section"), selection: $tab) {
                        ForEach(BentoTab.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .fixedSize()
                }
            }
        }
        .onChange(of: router.homeRequests) { _, _ in tab = .home }
    }
}

// MARK: - Home grid

struct BentoHome: View {
    @Environment(SkinStore.self) private var store
    @Environment(SkinPreferences.self) private var preferences
    @Environment(\.skinTheme) private var theme
    @Environment(\.skinConfiguration) private var configuration
    @Environment(\.horizontalSizeClass) private var sizeClass
    let columns: Int
    @State private var editing = false

    private var modules: [BentoModuleID] {
        preferences.bentoModules.compactMap(BentoModuleID.init(rawValue:)).filter(isAvailable)
    }

    private var hidden: [BentoModuleID] {
        BentoModuleID.allCases.filter { !preferences.bentoModules.contains($0.rawValue) && isAvailable($0) }
    }

    private var effectiveColumns: Int {
        #if os(macOS)
            columns
        #else
            sizeClass == .regular ? 4 : 2
        #endif
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(verbatim: configuration.appName.uppercased())
                        .font(SkinFonts.dot(28))
                        .foregroundStyle(theme.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Spacer()
                    Button {
                        withAnimation(.snappy) { editing.toggle() }
                    } label: {
                        Text(editing ? SkinL("Done") : SkinL("Edit"))
                            .font(.subheadline.weight(.bold))
                            .padding(.horizontal, 16)
                            .frame(height: 36)
                            .foregroundStyle(editing ? .white : theme.text)
                            .background(editing ? theme.accent : .clear, in: Capsule())
                            .overlay(Capsule().strokeBorder(editing ? .clear : theme.text, lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)
                }
                if !store.hasProfiles {
                    NoProfileView()
                } else {
                    BentoFlowGrid(modules: modules, columns: effectiveColumns, editing: editing)
                    if editing {
                        BentoTray(modules: hidden)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 16)
            .frame(maxWidth: 1400)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .background(theme.background)
        #if os(iOS)
        .toolbar(sizeClass == .regular ? .automatic : .hidden, for: .navigationBar)
        #endif
    }

    private func isAvailable(_ module: BentoModuleID) -> Bool {
        module != .systemProxy || store.systemProxy.available
    }
}

extension BentoModuleID {
    /// Column span for a given grid width.
    func span(columns: Int) -> Int {
        switch (self, columns) {
        case (.download, 2), (.stats, 2), (.groups, _), (.logs, 2), (.totals, 2): columns
        case (.download, _): max(columns / 2, 2)
        case (.stats, _), (.logs, _), (.totals, _): 2
        default: 1
        }
    }

    var height: CGFloat {
        switch self {
        case .download: 196
        case .power, .node: 150
        case .stats: 96
        case .groups: 170
        case .logs: 150
        default: 118
        }
    }
}

/// Packs modules into rows by span; each row takes the tallest module's height.
private struct BentoFlowGrid: View {
    @Environment(SkinPreferences.self) private var preferences
    let modules: [BentoModuleID]
    let columns: Int
    let editing: Bool

    private var rows: [[BentoModuleID]] {
        var rows: [[BentoModuleID]] = []
        var current: [BentoModuleID] = []
        var used = 0
        for module in modules {
            let span = min(module.span(columns: columns), columns)
            if used + span > columns {
                rows.append(current)
                current = []
                used = 0
            }
            current.append(module)
            used += span
        }
        if !current.isEmpty { rows.append(current) }
        return rows
    }

    var body: some View {
        VStack(spacing: 10) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                GeometryReader { proxy in
                    let unit = (proxy.size.width - CGFloat(columns - 1) * 10) / CGFloat(columns)
                    HStack(spacing: 10) {
                        ForEach(row) { module in
                            let span = min(module.span(columns: columns), columns)
                            BentoTile(module: module, editing: editing)
                                .frame(width: unit * CGFloat(span) + CGFloat(span - 1) * 10)
                        }
                    }
                }
                .frame(height: row.map(\.height).max() ?? 118)
            }
        }
    }
}

private struct BentoTile: View {
    @Environment(SkinPreferences.self) private var preferences
    @Environment(\.skinTheme) private var theme
    let module: BentoModuleID
    let editing: Bool

    var body: some View {
        BentoModuleView(module: module)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay {
                if editing {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6, 5]))
                        .foregroundStyle(theme.text.opacity(0.3))
                }
            }
            .overlay(alignment: .topLeading) {
                if editing {
                    Button {
                        withAnimation(.snappy) { preferences.bentoModules.removeAll { $0 == module.rawValue } }
                    } label: {
                        Image(systemName: "minus")
                            .font(.system(size: 13, weight: .black))
                            .foregroundStyle(.white)
                            .frame(width: 26, height: 26)
                            .background(Color(hex: 0x0F0F0F), in: Circle())
                            .overlay(Circle().strokeBorder(theme.background, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                    .offset(x: -6, y: -6)
                    .accessibilityLabel(Text(SkinL("Remove %@", module.title)))
                }
            }
            .rotationEffect(.degrees(editing ? (module.rawValue.count.isMultiple(of: 2) ? -0.6 : 0.6) : 0))
            .allowsHitTesting(true)
            .draggable(module.rawValue) {
                Text(module.title).padding(10).background(theme.surface, in: Capsule())
            }
            .dropDestination(for: String.self) { items, _ in
                guard let dragged = items.first, dragged != module.rawValue else { return false }
                var order = preferences.bentoModules
                guard let from = order.firstIndex(of: dragged), let to = order.firstIndex(of: module.rawValue) else { return false }
                order.remove(at: from)
                order.insert(dragged, at: to)
                withAnimation(.snappy) { preferences.bentoModules = order }
                return true
            }
    }
}

/// Modules not on the home grid; tap to add.
private struct BentoTray: View {
    @Environment(SkinPreferences.self) private var preferences
    @Environment(\.skinTheme) private var theme
    let modules: [BentoModuleID]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(skin: "Add Modules").font(.headline).foregroundStyle(theme.text)
            Text(skin: "Tap to add. Drag tiles to reorder.").font(.caption).foregroundStyle(theme.secondaryText)
            if modules.isEmpty {
                Text(skin: "Everything is already on your home.").font(.subheadline).foregroundStyle(theme.secondaryText).padding(.vertical, 8)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 10)], spacing: 10) {
                ForEach(modules) { module in
                    Button {
                        withAnimation(.snappy) { preferences.bentoModules.append(module.rawValue) }
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: module.symbol).font(.system(size: 20, weight: .semibold))
                            Text(module.title).font(.caption.weight(.bold)).lineLimit(1).minimumScaleFactor(0.8)
                        }
                        .foregroundStyle(theme.text)
                        .frame(maxWidth: .infinity)
                        .frame(height: 84)
                        .background(theme.elevatedSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                    .buttonStyle(SkinPressStyle())
                }
            }
            Button(SkinL("Reset Layout")) {
                withAnimation(.snappy) { preferences.bentoModules = BentoModuleID.defaultOrder.map(\.rawValue) }
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(theme.accent)
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(18)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}
