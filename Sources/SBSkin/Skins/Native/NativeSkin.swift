import SBSkinShared
import SwiftUI

/// A · System Native. Pure Apple: Liquid Glass tab bar with a live status accessory on
/// iPhone, a floating glass sidebar with a unified toolbar on iPad and Mac.
struct NativeSkin: View {
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        Group {
            #if os(macOS)
                NativeRegular()
            #else
                if sizeClass == .regular {
                    NativeRegular()
                } else {
                    NativeCompact()
                }
            #endif
        }
        .skinSheets()
    }
}

enum NativeTab: String, Hashable, CaseIterable {
    case dashboard, groups, connections, logs, tools, settings

    var title: String {
        switch self {
        case .dashboard: SkinL("Dashboard")
        case .groups: SkinL("Groups")
        case .connections: SkinL("Connections")
        case .logs: SkinL("Logs")
        case .tools: SkinL("Tools")
        case .settings: SkinL("Settings")
        }
    }

    var symbol: String {
        switch self {
        case .dashboard: "gauge.with.dots.needle.33percent"
        case .groups: "square.grid.2x2"
        case .connections: "arrow.left.arrow.right"
        case .logs: "list.bullet.rectangle"
        case .tools: "wrench.and.screwdriver"
        case .settings: "gearshape"
        }
    }
}

// MARK: - iPhone

private struct NativeCompact: View {
    @Environment(SkinStore.self) private var store
    @Environment(SkinRouter.self) private var router
    @Environment(\.skinConfiguration) private var configuration
    @State private var tab: NativeTab = .dashboard

    var body: some View {
        TabView(selection: $tab) {
            Tab(NativeTab.dashboard.title, systemImage: NativeTab.dashboard.symbol, value: NativeTab.dashboard) {
                NavigationStack { NativeDashboard() }
            }
            Tab(NativeTab.groups.title, systemImage: NativeTab.groups.symbol, value: NativeTab.groups) {
                NavigationStack { NodesPage() }
            }
            Tab(NativeTab.logs.title, systemImage: NativeTab.logs.symbol, value: NativeTab.logs) {
                NavigationStack { LogsPage() }
            }
            if let tools = configuration.hostPages.tools {
                Tab(NativeTab.tools.title, systemImage: NativeTab.tools.symbol, value: NativeTab.tools) {
                    NavigationStack { tools() }
                }
                .badge(configuration.hostPages.toolsBadge())
            } else {
                Tab(NativeTab.connections.title, systemImage: NativeTab.connections.symbol, value: NativeTab.connections) {
                    NavigationStack { ConnectionsPage() }
                }
            }
            Tab(NativeTab.settings.title, systemImage: NativeTab.settings.symbol, value: NativeTab.settings) {
                NavigationStack { MorePage() }
            }
        }
        #if os(iOS)
        .tabBarMinimizeBehavior(.onScrollDown)
        .tabViewBottomAccessory {
            NativeStatusAccessory()
        }
        #endif
        .onChange(of: router.homeRequests) { _, _ in tab = .dashboard }
    }
}

/// The glass pill above the tab bar: status, node and live speed. Tap for nodes.
struct NativeStatusAccessory: View {
    @Environment(SkinStore.self) private var store
    @Environment(SkinRouter.self) private var router
    @Environment(\.skinTheme) private var theme

    var body: some View {
        HStack(spacing: 10) {
            StatusDot(phase: store.phase)
            if store.isRunning {
                Button {
                    router.showNodes()
                } label: {
                    Text(store.currentNode?.tag ?? store.phase.label)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
                Spacer(minLength: 6)
                Text(verbatim: "↑ \(SkinFormat.rate(store.status.uplink))")
                    .foregroundStyle(theme.upload)
                Text(verbatim: "↓ \(SkinFormat.rate(store.status.downlink))")
                    .foregroundStyle(theme.download)
            } else {
                Text(store.phase.label).font(.subheadline.weight(.semibold))
                Spacer()
                Button(SkinL("Start")) { store.startService() }
                    .font(.subheadline.weight(.semibold))
                    .disabled(store.phase != .stopped)
            }
        }
        .font(.caption.monospacedDigit())
        .padding(.horizontal, 16)
    }
}

// MARK: - iPad / Mac

private struct NativeRegular: View {
    @Environment(SkinStore.self) private var store
    @Environment(SkinRouter.self) private var router
    @Environment(\.skinConfiguration) private var configuration
    @Environment(\.skinTheme) private var theme
    @State private var selection: NativeTab? = .dashboard

    private var tabs: [NativeTab] {
        var tabs: [NativeTab] = [.dashboard, .groups, .connections, .logs]
        if configuration.hostPages.tools != nil { tabs.append(.tools) }
        tabs.append(.settings)
        return tabs
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section {
                    NativeProfileSwitcher()
                }
                Section {
                    ForEach(tabs, id: \.self) { tab in
                        Label(tab.title, systemImage: tab.symbol)
                            .badge(badge(for: tab))
                            .tag(tab)
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 230, max: 280)
            .safeAreaInset(edge: .bottom) {
                Text(verbatim: configuration.appName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
            }
        } detail: {
            NavigationStack {
                detail(for: selection ?? .dashboard)
            }
            .toolbar { NativeServiceToolbar() }
        }
        .onChange(of: router.homeRequests) { _, _ in selection = .dashboard }
    }

    private func badge(for tab: NativeTab) -> Int {
        switch tab {
        case .connections: store.isRunning ? store.activeConnections.count : 0
        case .tools: configuration.hostPages.toolsBadge()
        default: 0
        }
    }

    @ViewBuilder
    private func detail(for tab: NativeTab) -> some View {
        switch tab {
        case .dashboard: NativeDashboard()
        case .groups: NodesPage()
        case .connections: ConnectionsPage()
        case .logs: LogsPage()
        case .tools: configuration.hostPages.tools?() ?? AnyView(EmptyView())
        case .settings: MorePage()
        }
    }
}

/// Profile card at the top of the sidebar.
private struct NativeProfileSwitcher: View {
    @Environment(SkinStore.self) private var store
    @Environment(\.skinTheme) private var theme

    var body: some View {
        Menu {
            ForEach(store.profiles) { profile in
                Button {
                    store.selectProfile(profile.id)
                } label: {
                    if profile.id == store.selectedProfileID {
                        Label(profile.name, systemImage: "checkmark")
                    } else {
                        Text(profile.name)
                    }
                }
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: store.activeProfile?.isRemote == true ? "icloud.fill" : "doc.text.fill")
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(theme.accent, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text(store.activeProfile?.name ?? SkinL("No Profile"))
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text(store.phase.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .disabled(store.profiles.isEmpty)
    }
}

/// Mode picker, system proxy switch and start/stop in the window toolbar.
struct NativeServiceToolbar: ToolbarContent {
    @Environment(SkinStore.self) private var store
    @Environment(SkinPreferences.self) private var preferences

    var body: some ToolbarContent {
        if store.isRunning, store.clashModes.count > 1 {
            ToolbarItem(placement: .principal) {
                Picker(SkinL("Mode"), selection: Binding(get: { store.clashMode }, set: { store.setClashMode($0) })) {
                    ForEach(store.clashModes, id: \.self) { mode in
                        Text(preferences.vocabulary.modeShort(mode)).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }
        }
        if store.isRunning, store.systemProxy.available {
            ToolbarItem(placement: .primaryAction) {
                Toggle(isOn: Binding(get: { store.systemProxy.enabled }, set: { store.setSystemProxy($0) })) {
                    Label(SkinL("System Proxy"), systemImage: "network")
                }
                .toggleStyle(.button)
                .help(SkinL("System Proxy"))
            }
        }
        ToolbarItem(placement: .primaryAction) {
            Button {
                store.toggleService()
            } label: {
                if store.phase.isTransitioning {
                    ProgressView().controlSize(.small)
                } else {
                    Label(store.phase.isActive ? SkinL("Stop") : SkinL("Start"), systemImage: store.phase.isActive ? "stop.fill" : "play.fill")
                }
            }
            .disabled(store.phase == .unavailable || store.phase.isTransitioning)
            .help(store.phase.isActive ? SkinL("Stop") : SkinL("Start"))
        }
    }
}
