import SBSkinShared
import SwiftUI

/// iPad / Mac layout: icon rail · live dashboard with connection table · inspector.
struct InstrumentRegular: View {
    @Environment(SkinStore.self) private var store
    @Environment(SkinRouter.self) private var router
    @Environment(\.skinTheme) private var theme
    @Environment(\.skinConfiguration) private var configuration
    @State private var tab: InstrumentTab = .home

    var body: some View {
        HStack(spacing: 0) {
            rail
            Divider().overlay(theme.separator)
            NavigationStack {
                Group {
                    switch tab {
                    case .home: InstrumentDeck()
                    case .groups: InstrumentNodesPage()
                    case .connections: ConnectionsPage()
                    case .logs: LogsPage()
                    case .more: MorePage()
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .primaryAction) { InstrumentPowerButton(size: 34) }
                }
            }
            if tab == .home {
                Divider().overlay(theme.separator)
                InstrumentInspector()
                    .frame(width: 320)
            }
        }
        .background(theme.background)
        .onChange(of: router.homeRequests) { _, _ in tab = .home }
    }

    private var rail: some View {
        VStack(spacing: 6) {
            ForEach(InstrumentTab.allCases, id: \.self) { item in
                let selected = item == tab
                Button {
                    tab = item
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: item.symbol).font(.system(size: 18, weight: .semibold))
                        Text(item.title).font(.system(size: 9, weight: .medium)).lineLimit(1).minimumScaleFactor(0.7)
                    }
                    .foregroundStyle(selected ? theme.accent : theme.secondaryText)
                    .frame(width: 58, height: 52)
                    .background(selected ? theme.accent.opacity(0.16) : .clear, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(item.title))
            }
            Spacer()
            Text(configuration.appName.prefix(1).uppercased())
                .font(.system(size: 13, weight: .heavy, design: .monospaced))
                .foregroundStyle(theme.secondaryText)
                .padding(.bottom, 16)
        }
        .padding(.top, 52)
        .frame(width: 74)
        .background(Color(hex: 0x0E1115))
    }
}

/// Main dashboard column: headline numbers, big chart, live connection table.
private struct InstrumentDeck: View {
    @Environment(SkinStore.self) private var store
    @Environment(\.skinTheme) private var theme
    @Environment(\.skinConfiguration) private var configuration

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 10) {
                    Text(configuration.appName.uppercased()).font(.caption.weight(.semibold)).tracking(3).foregroundStyle(theme.secondaryText)
                    Text(verbatim: "/").foregroundStyle(theme.separator)
                    Text(skin: "Dashboard").font(.subheadline.weight(.semibold)).foregroundStyle(theme.text)
                    Spacer()
                    if store.isRunning {
                        HStack(spacing: 6) {
                            Circle().fill(theme.accent).frame(width: 7, height: 7)
                            Text(store.phase.label)
                            ElapsedText(since: store.connectedSince)
                        }
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(theme.accent)
                        .padding(.horizontal, 12)
                        .frame(height: 28)
                        .background(theme.accent.opacity(0.12), in: Capsule())
                    }
                }
                if store.needsGate {
                    NoProfileView()
                } else if store.isRunning {
                    HStack(alignment: .bottom, spacing: 40) {
                        figure(SkinL("Download"), store.status.downlink, theme.download)
                        figure(SkinL("Upload"), store.status.uplink, theme.upload)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 3) {
                            Text(SkinL("Memory %@ · Goroutines %lld", SkinFormat.bytes(store.status.memory), store.status.goroutines))
                            Text(SkinL("Connections %lld in / %lld out", store.status.connectionsIn, store.status.connectionsOut))
                            Text(SkinL("Total ↓ %@ ↑ %@", SkinFormat.bytes(store.status.downlinkTotal), SkinFormat.bytes(store.status.uplinkTotal)))
                        }
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(theme.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    }
                    DualTrafficChart(download: store.downlinkHistory, upload: store.uplinkHistory, downloadColor: theme.download, uploadColor: theme.upload, gridColor: .white.opacity(0.06))
                        .frame(height: 180)
                    InstrumentConnectionTable()
                } else {
                    Text(store.phase.label)
                        .font(.system(size: 48, weight: .semibold, design: .monospaced))
                        .foregroundStyle(theme.secondaryText)
                        .padding(.top, 60)
                }
            }
            .padding(24)
        }
        .background(theme.background)
        .toolbar(removing: .title)
    }

    private func figure(_ title: String, _ rate: Int64, _ color: Color) -> some View {
        let parts = SkinFormat.rateParts(rate)
        return VStack(alignment: .leading, spacing: 0) {
            Text(title).font(.caption).foregroundStyle(theme.secondaryText)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(parts.value).font(.system(size: 46, weight: .semibold, design: .monospaced)).tracking(-1).foregroundStyle(color).contentTransition(.numericText())
                Text(parts.unit).font(.system(size: 14, design: .monospaced)).foregroundStyle(theme.secondaryText)
            }
        }
    }
}

/// Live connections as a dense table.
private struct InstrumentConnectionTable: View {
    @Environment(SkinStore.self) private var store
    @Environment(\.skinTheme) private var theme
    @State private var confirmCloseAll = false
    @State private var width: CGFloat = 800

    private var showsRule: Bool { width > 760 }

    var body: some View {
        let rows = store.activeConnections.sorted { $0.downlink + $0.uplink > $1.downlink + $1.uplink }.prefix(40)
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(skin: "Live Connections").font(.subheadline.weight(.semibold)).foregroundStyle(theme.text)
                Spacer()
                Text(SkinL("%lld active", rows.count)).font(.caption).foregroundStyle(theme.secondaryText)
                Button(SkinL("Close All")) { confirmCloseAll = true }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(SkinPalette.bad)
                    .buttonStyle(.plain)
                    .padding(.horizontal, 10)
                    .frame(height: 26)
                    .overlay(Capsule().strokeBorder(SkinPalette.bad.opacity(0.4)))
            }
            VStack(spacing: 0) {
                header
                ForEach(Array(rows)) { connection in
                    NavigationLink(value: connection.id) {
                        row(connection)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(SkinL("Close Connection"), role: .destructive) { store.close(connection) }
                    }
                }
            }
            .background(Color(hex: 0x0E1115), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(theme.separator))
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        }
        .navigationDestination(for: String.self) { ConnectionDetailPage(connectionID: $0) }
        .confirmationDialog(SkinL("Close all connections?"), isPresented: $confirmCloseAll, titleVisibility: .visible) {
            Button(SkinL("Close All"), role: .destructive) { store.closeAllConnections() }
        }
        .subscribesToConnections(store)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text(skin: "Destination").frame(maxWidth: .infinity, alignment: .leading)
            if showsRule { Text(skin: "Rule").frame(width: 140, alignment: .leading) }
            Text(skin: "Route").frame(width: 150, alignment: .leading)
            Text(verbatim: "↓ / ↑").frame(width: 150, alignment: .trailing)
            Text(skin: "Time").frame(width: 48, alignment: .trailing)
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(theme.secondaryText)
        .padding(.horizontal, 14)
        .frame(height: 34)
        .overlay(alignment: .bottom) { Rectangle().fill(theme.separator).frame(height: 1) }
    }

    private func row(_ connection: SkinConnection) -> some View {
        HStack(spacing: 8) {
            Text(connection.displayDestination).foregroundStyle(theme.text).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
            if showsRule {
                Text(connection.ruleSummary).foregroundStyle(theme.secondaryText).lineLimit(1).frame(width: 140, alignment: .leading)
            }
            Text(connection.isDirect ? SkinL("Direct") : connection.outbound).foregroundStyle(connection.isDirect ? theme.secondaryText : theme.accent).lineLimit(1).frame(width: 150, alignment: .leading)
            Text(verbatim: "\(SkinFormat.rate(connection.downlink)) / \(SkinFormat.rate(connection.uplink))").foregroundStyle(theme.text.opacity(0.85)).lineLimit(1).minimumScaleFactor(0.7).frame(width: 150, alignment: .trailing)
            Text(verbatim: SkinFormat.duration(Date().timeIntervalSince(connection.createdAt))).foregroundStyle(theme.secondaryText).lineLimit(1).frame(width: 48, alignment: .trailing)
        }
        .font(.system(size: 12, design: .monospaced))
        .padding(.horizontal, 14)
        .frame(height: 32)
        .contentShape(Rectangle())
    }
}

/// Right column: profile, mode, system proxy and the primary group's nodes.
private struct InstrumentInspector: View {
    @Environment(SkinStore.self) private var store
    @Environment(SkinRouter.self) private var router
    @Environment(\.skinTheme) private var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                label(SkinL("Profile"))
                Button {
                    router.sheet = .profiles
                } label: {
                    HStack {
                        Text(store.activeProfile?.name ?? SkinL("No Profile")).font(.subheadline.weight(.semibold)).foregroundStyle(theme.text)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down").font(.caption).foregroundStyle(theme.secondaryText)
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 42)
                    .background(theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(theme.separator))
                }
                .buttonStyle(.plain)

                if store.isRunning {
                    label(SkinL("Mode"))
                    InstrumentModeButtons()
                    if store.systemProxy.available {
                        Toggle(SkinL("System Proxy"), isOn: Binding(get: { store.systemProxy.enabled }, set: { store.setSystemProxy($0) }))
                            .font(.subheadline)
                            .foregroundStyle(theme.text)
                            .tint(theme.accent)
                    }
                    if let group = store.primaryGroup {
                        HStack {
                            label(group.tag)
                            Spacer()
                            Button {
                                store.urlTest(group.tag)
                            } label: {
                                if store.testingGroups.contains(group.tag) {
                                    ProgressView().controlSize(.small)
                                } else {
                                    Text(skin: "Test").font(.caption.weight(.semibold)).foregroundStyle(theme.accent)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        VStack(spacing: 3) {
                            ForEach(group.items) { item in
                                let selected = item.tag == group.selected
                                Button {
                                    store.select(item.tag, in: group.tag)
                                } label: {
                                    HStack(spacing: 10) {
                                        Text(item.tag).font(.subheadline.weight(selected ? .semibold : .regular)).foregroundStyle(theme.text).lineLimit(1)
                                        Spacer()
                                        SignalBars(grade: item.grade, activeColor: theme.accent, inactiveColor: .white.opacity(0.12))
                                        LatencyText(delay: item.delay, font: .system(size: 12, weight: .semibold, design: .monospaced))
                                            .frame(width: 60, alignment: .trailing)
                                    }
                                    .padding(.horizontal, 10)
                                    .frame(height: 34)
                                    .background(selected ? theme.accent.opacity(0.14) : .clear, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .disabled(!group.selectable)
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(Color(hex: 0x0E1115))
    }

    private func label(_ text: String) -> some View {
        Text(text).font(.caption.weight(.semibold)).foregroundStyle(theme.secondaryText)
    }
}
