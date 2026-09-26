import SBSkinShared
import SwiftUI

/// Renders one Bento module.
struct BentoModuleView: View {
    @Environment(SkinStore.self) private var store
    @Environment(SkinRouter.self) private var router
    @Environment(SkinPreferences.self) private var preferences
    @Environment(\.skinTheme) private var theme
    let module: BentoModuleID

    var body: some View {
        switch module {
        case .download: download
        case .power: power
        case .node: node
        case .mode: mode
        case .upload: upload
        case .stats: stats
        case .totals: totals
        case .systemProxy: systemProxy
        case .profile: profile
        case .groups: groups
        case .connections: connections
        case .logs: logs
        }
    }

    // MARK: Modules

    private var download: some View {
        let parts = SkinFormat.rateParts(store.status.downlink)
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(skin: "Download")
                Spacer()
                Text(SkinL("Session %@", SkinFormat.bytes(store.status.downlinkTotal)))
            }
            .font(.caption.weight(.bold))
            .foregroundStyle(Color(hex: 0x9A9A9A))
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(store.isRunning ? parts.value : "0.0")
                    .font(SkinFonts.dot(84))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .contentTransition(.numericText())
                Text(parts.unit.uppercased()).font(.caption.weight(.bold)).foregroundStyle(Color(hex: 0x9A9A9A))
            }
            .foregroundStyle(.white)
            .padding(.top, 6)
            Spacer(minLength: 6)
            BarHistogram(values: Array(store.downlinkHistory.suffix(32)), color: .white, highlight: theme.accent)
                .frame(height: 36)
        }
        .padding(18)
        .background(Color(hex: 0x0F0F0F))
    }

    private var power: some View {
        let on = store.phase.isActive
        return Button {
            store.toggleService()
        } label: {
            VStack(alignment: .leading) {
                Text(skin: "Connection").font(.caption.weight(.bold)).opacity(0.85)
                Spacer()
                Text(verbatim: on ? "ON" : "OFF").font(SkinFonts.dot(52)).lineLimit(1)
                Spacer()
                if on {
                    ElapsedText(since: store.connectedSince).font(.caption.weight(.bold))
                } else {
                    Text(store.phase.label).font(.caption.weight(.bold))
                }
            }
            .foregroundStyle(on ? .white : theme.text)
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(on ? theme.accent : theme.surface)
        }
        .buttonStyle(SkinPressStyle())
        .disabled(store.phase == .unavailable || store.phase.isTransitioning)
        .sensoryFeedback(.impact, trigger: on)
    }

    private var node: some View {
        let group = store.primaryGroup
        let node = store.currentNode
        return Button {
            router.showNodes(group: group?.tag)
        } label: {
            VStack(alignment: .leading) {
                Text(group?.tag ?? SkinL("Node")).font(.caption.weight(.bold)).foregroundStyle(theme.secondaryText).lineLimit(1)
                Spacer()
                Text(node.map { SkinRegion.stripFlag($0.tag) } ?? "—").font(.system(size: 22, weight: .heavy)).foregroundStyle(theme.text).lineLimit(2).minimumScaleFactor(0.6)
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(verbatim: node.map { $0.delay > 0 && $0.delay != .max ? "\($0.delay)" : "--" } ?? "--").font(SkinFonts.dot(30))
                    Text(verbatim: "MS").font(.caption2.weight(.bold)).foregroundStyle(theme.secondaryText)
                }
                .foregroundStyle(theme.text)
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(theme.surface)
        }
        .buttonStyle(SkinPressStyle())
        .disabled(group == nil)
    }

    private var mode: some View {
        VStack(alignment: .leading) {
            Text(skin: "Mode").font(.caption.weight(.bold)).foregroundStyle(theme.secondaryText)
            Spacer()
            HStack(spacing: 5) {
                ForEach(store.clashModes, id: \.self) { mode in
                    let selected = mode == store.clashMode
                    Button {
                        store.setClashMode(mode)
                    } label: {
                        Text(preferences.vocabulary.modeShort(mode))
                            .font(.caption.weight(.heavy))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .frame(maxWidth: .infinity)
                            .frame(height: 36)
                            .foregroundStyle(selected ? theme.background : theme.text)
                            .background(selected ? theme.text : theme.elevatedSurface, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            if store.clashModes.isEmpty {
                Text(store.phase.label).font(.caption).foregroundStyle(theme.secondaryText)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(theme.surface)
    }

    private var upload: some View {
        let parts = SkinFormat.rateParts(store.status.uplink)
        return VStack(alignment: .leading) {
            Text(skin: "Upload").font(.caption.weight(.bold)).foregroundStyle(theme.secondaryText)
            Spacer()
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(store.isRunning ? parts.value : "0.0").font(SkinFonts.dot(40)).lineLimit(1).minimumScaleFactor(0.5).contentTransition(.numericText())
                Text(parts.unit.uppercased()).font(.caption2.weight(.bold)).foregroundStyle(theme.secondaryText)
            }
            .foregroundStyle(theme.text)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(theme.surface)
    }

    private var stats: some View {
        HStack {
            stat(SkinL("Connections"), "\(store.status.totalConnections)")
            stat(SkinL("Memory MB"), "\(store.status.memory / 1_000_000)")
            stat(SkinL("Goroutines"), "\(store.status.goroutines)")
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.surface)
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption2.weight(.bold)).foregroundStyle(theme.secondaryText).lineLimit(1)
            Text(value).font(SkinFonts.dot(28)).foregroundStyle(theme.text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var totals: some View {
        HStack {
            stat(SkinL("Received"), SkinFormat.bytes(store.status.downlinkTotal))
            stat(SkinL("Sent"), SkinFormat.bytes(store.status.uplinkTotal))
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.surface)
    }

    private var systemProxy: some View {
        let on = store.systemProxy.enabled
        return Button {
            store.setSystemProxy(!on)
        } label: {
            VStack(alignment: .leading) {
                Text(skin: "System Proxy").font(.caption.weight(.bold)).foregroundStyle(theme.secondaryText)
                Spacer()
                Text(verbatim: on ? "ON" : "OFF").font(SkinFonts.dot(40)).foregroundStyle(on ? theme.accent : theme.text)
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(theme.surface)
        }
        .buttonStyle(SkinPressStyle())
        .disabled(!store.isRunning)
    }

    private var profile: some View {
        Button {
            router.sheet = .profiles
        } label: {
            VStack(alignment: .leading) {
                Text(skin: "Profile").font(.caption.weight(.bold)).foregroundStyle(theme.secondaryText)
                Spacer()
                Text(store.activeProfile?.name ?? "—").font(.headline.weight(.heavy)).foregroundStyle(theme.text).lineLimit(2)
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(theme.surface)
        }
        .buttonStyle(SkinPressStyle())
    }

    private var groups: some View {
        let group = store.primaryGroup
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(group.map { SkinL("Outbound Group · %@", $0.tag) } ?? SkinL("Outbound Groups")).font(.caption.weight(.bold)).foregroundStyle(theme.secondaryText)
                Spacer()
                if let group {
                    Button(SkinL("Test")) { store.urlTest(group.tag) }
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(theme.accent)
                        .buttonStyle(.plain)
                }
            }
            if let group {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 6)], spacing: 6) {
                        ForEach(group.items) { item in
                            let selected = item.tag == group.selected
                            Button {
                                store.select(item.tag, in: group.tag)
                            } label: {
                                HStack {
                                    Text(SkinRegion.stripFlag(item.tag)).font(.caption.weight(.bold)).lineLimit(1)
                                    Spacer(minLength: 2)
                                    Text(verbatim: item.delay > 0 && item.delay != .max ? "\(item.delay)" : "--").font(SkinFonts.dot(15))
                                }
                                .padding(.horizontal, 10)
                                .frame(height: 38)
                                .foregroundStyle(selected ? theme.background : theme.text)
                                .background(selected ? theme.text : theme.elevatedSurface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .disabled(!group.selectable)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(theme.surface)
    }

    private var connections: some View {
        NavigationLink {
            ConnectionsPage()
        } label: {
            VStack(alignment: .leading) {
                Text(skin: "Connections").font(.caption.weight(.bold)).foregroundStyle(theme.secondaryText)
                Spacer()
                Text(verbatim: "\(store.status.totalConnections)").font(SkinFonts.dot(40)).foregroundStyle(theme.text)
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(theme.surface)
        }
        .buttonStyle(SkinPressStyle())
    }

    private var logs: some View {
        NavigationLink {
            LogsPage()
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(skin: "Logs").font(.caption.weight(.bold)).foregroundStyle(Color(hex: 0x9A9A9A))
                ForEach(store.logs.suffix(6)) { entry in
                    Text(entry.plainMessage)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(entry.level <= .warn ? theme.accent : .white.opacity(0.8))
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color(hex: 0x0F0F0F))
        }
        .buttonStyle(SkinPressStyle())
        .subscribesToLogs(store)
    }
}
