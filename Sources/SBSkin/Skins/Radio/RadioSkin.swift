import SBSkinShared
import SwiftUI

/// G · Radio. Nodes are stations: turn the knob to tune, the LCD shows what's playing, and the
/// log prints out like a receipt.
struct RadioSkin: View {
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        NavigationStack {
            Group {
                #if os(macOS)
                    RadioDesk()
                #else
                    if sizeClass == .regular { RadioDesk() } else { RadioHandheld() }
                #endif
            }
            .toolbar(.hidden)
            .navigationDestination(for: RadioPage.self) { page in
                switch page {
                case .receipt: RadioReceipt()
                case .groups: NodesPage()
                case .connections: ConnectionsPage()
                case .settings: MorePage()
                }
            }
        }
        .skinSheets()
    }
}

enum RadioPage: Hashable {
    case receipt, groups, connections, settings
}

/// Shared tuning state for both layouts.
private struct RadioController: View {
    @Environment(SkinStore.self) private var store
    @Environment(SkinPreferences.self) private var preferences
    @State private var tunedIndex = 0
    let content: (RadioContext) -> AnyView

    var body: some View {
        let tuning = RadioTuning(store: store, preferences: preferences)
        let band = tuning.band
        let stations = band?.items ?? []
        let context = RadioContext(
            band: band,
            stations: stations,
            tunedIndex: Binding(get: { min(tunedIndex, max(stations.count - 1, 0)) }, set: { tunedIndex = $0 }),
            commit: { index in
                guard let band, stations.indices.contains(index) else { return }
                store.select(stations[index].tag, in: band.tag)
            },
            nextBand: { tuning.nextBand() }
        )
        content(context)
            .onAppear { syncIndex(band) }
            .onChange(of: band?.selected) { _, _ in syncIndex(band) }
            .onChange(of: band?.tag) { _, _ in syncIndex(band) }
    }

    private func syncIndex(_ band: SkinOutboundGroup?) {
        guard let band, let index = band.items.firstIndex(where: { $0.tag == band.selected }) else { return }
        tunedIndex = index
    }
}

struct RadioContext {
    let band: SkinOutboundGroup?
    let stations: [SkinOutbound]
    let tunedIndex: Binding<Int>
    let commit: (Int) -> Void
    let nextBand: () -> Void

    var tuned: SkinOutbound? {
        stations.indices.contains(tunedIndex.wrappedValue) ? stations[tunedIndex.wrappedValue] : nil
    }

    var channel: String {
        String(format: "CH %02d / %02d", tunedIndex.wrappedValue + 1, max(stations.count, 1))
    }
}

// MARK: - iPhone: a handheld radio

private struct RadioHandheld: View {
    @Environment(SkinStore.self) private var store
    @Environment(SkinRouter.self) private var router
    @Environment(SkinPreferences.self) private var preferences
    @Environment(\.skinTheme) private var theme
    @Environment(\.skinConfiguration) private var configuration

    var body: some View {
        RadioController { context in
            AnyView(
                ScrollView {
                    VStack(spacing: 18) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(configuration.appName.uppercased()).font(.system(size: 15, weight: .heavy)).tracking(3)
                            Spacer()
                            Button(store.activeProfile?.name ?? SkinL("No Profile")) { router.sheet = .profiles }
                                .font(.system(size: 11, weight: .bold))
                                .tracking(2)
                                .foregroundStyle(theme.secondaryText)
                                .buttonStyle(.plain)
                        }
                        .foregroundStyle(theme.text)
                        RadioGrille()
                        RadioLCD(
                            bandName: context.band?.tag ?? SkinL("No band"),
                            channel: context.channel,
                            station: store.isRunning ? (context.tuned.map { SkinRegion.stripFlag($0.tag) } ?? "—") : store.phase.label,
                            detail: detailLine(context)
                        )
                        RadioScale(stations: context.stations, tunedIndex: context.tunedIndex.wrappedValue) { index in
                            context.tunedIndex.wrappedValue = index
                            context.commit(index)
                        }
                        HStack(alignment: .top) {
                            VStack(spacing: 8) {
                                RadioKnob(diameter: 172, stationCount: context.stations.count, tunedIndex: context.tunedIndex, onCommit: context.commit)
                                label(SkinL("TUNE · STATION"))
                            }
                            Spacer()
                            VStack(spacing: 14) {
                                RadioPowerLever()
                                label(store.phase.isActive ? SkinL("POWER · ON") : SkinL("POWER · OFF"))
                                RadioKey(title: SkinL("Auto-seek"), isOn: context.band.map { store.testingGroups.contains($0.tag) } ?? false, dark: true, height: 44) {
                                    if let band = context.band { store.urlTest(band.tag) }
                                }
                                RadioKey(title: SkinL("Band"), isOn: false, height: 44) { context.nextBand() }
                            }
                            .frame(width: 118)
                        }
                        if store.clashModes.count > 1 {
                            HStack(spacing: 10) {
                                ForEach(store.clashModes, id: \.self) { mode in
                                    RadioKey(title: preferences.vocabulary.modeShort(mode), isOn: mode == store.clashMode) { store.setClashMode(mode) }
                                }
                            }
                        }
                        HStack {
                            navLabel(SkinL("● RECEIPT"), .receipt)
                            Spacer()
                            navLabel(SkinL("● BANDS"), .groups)
                            Spacer()
                            navLabel(SkinL("● LINES"), .connections)
                            Spacer()
                            navLabel(SkinL("● SETUP"), .settings)
                        }
                        .padding(.top, 6)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                }
                .scrollIndicators(.hidden)
                .background(theme.background)
            )
        }
    }

    private func detailLine(_ context: RadioContext) -> String {
        guard store.isRunning, let station = context.tuned else { return store.activeProfile?.name.uppercased() ?? "" }
        let delay = station.delay > 0 && station.delay != .max ? "\(station.delay)MS" : "--MS"
        let uptime = store.connectedSince.map { SkinFormat.duration(Date().timeIntervalSince($0)) } ?? ""
        return "\(delay) · \(station.type.uppercased()) · \(uptime)"
    }

    private func label(_ text: String) -> some View {
        Text(text).font(.system(size: 10, weight: .heavy)).tracking(2).foregroundStyle(theme.secondaryText)
    }

    private func navLabel(_ title: String, _ page: RadioPage) -> some View {
        NavigationLink(value: page) {
            Text(title).font(.system(size: 11, weight: .heavy)).tracking(2).foregroundStyle(theme.secondaryText)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - iPad / Mac: a desk radio with a receipt printer

private struct RadioDesk: View {
    @Environment(SkinStore.self) private var store
    @Environment(SkinRouter.self) private var router
    @Environment(SkinPreferences.self) private var preferences
    @Environment(\.skinTheme) private var theme
    @Environment(\.skinConfiguration) private var configuration

    var body: some View {
        RadioController { context in
            AnyView(
                ScrollView {
                    VStack(spacing: 22) {
                        VStack(spacing: 18) {
                            HStack {
                                Text(configuration.appName.uppercased()).font(.system(size: 14, weight: .heavy)).tracking(3)
                                Text(verbatim: "·").foregroundStyle(theme.secondaryText)
                                Button(store.activeProfile?.name ?? "") { router.sheet = .profiles }.buttonStyle(.plain).font(.system(size: 11, weight: .bold)).tracking(2).foregroundStyle(theme.secondaryText)
                                Spacer()
                                RadioGrille(rows: 3).frame(width: 260)
                            }
                            .foregroundStyle(theme.text)
                            HStack(alignment: .center, spacing: 20) {
                                RadioLCD(
                                    bandName: context.band?.tag ?? "",
                                    channel: context.channel,
                                    station: store.isRunning ? (context.tuned.map { SkinRegion.stripFlag($0.tag) } ?? "—") : store.phase.label,
                                    detail: store.isRunning ? "↓\(SkinFormat.rate(store.status.downlink))  ↑\(SkinFormat.rate(store.status.uplink))" : "",
                                    large: true
                                )
                                .frame(width: 360)
                                RadioScale(stations: context.stations, tunedIndex: context.tunedIndex.wrappedValue) { index in
                                    context.tunedIndex.wrappedValue = index
                                    context.commit(index)
                                }
                                .frame(height: 72)
                                RadioKnob(diameter: 150, stationCount: context.stations.count, tunedIndex: context.tunedIndex, onCommit: context.commit)
                            }
                            HStack(spacing: 10) {
                                ForEach(store.clashModes, id: \.self) { mode in
                                    RadioKey(title: preferences.vocabulary.modeShort(mode), isOn: mode == store.clashMode) { store.setClashMode(mode) }
                                }
                                RadioKey(title: SkinL("Auto-seek"), isOn: context.band.map { store.testingGroups.contains($0.tag) } ?? false, dark: true) {
                                    if let band = context.band { store.urlTest(band.tag) }
                                }
                                RadioKey(title: SkinL("Band"), isOn: false, dark: true) { context.nextBand() }
                                RadioKey(title: SkinL("Setup"), isOn: false, dark: true) { router.sheet = .more }
                                RadioPowerLever(vertical: false)
                            }
                        }
                        .padding(28)
                        .background(theme.background, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
                        .shadow(color: .black.opacity(0.25), radius: 30, y: 20)

                        HStack(alignment: .top, spacing: 22) {
                            RadioReceiptPaper(maxLines: 18)
                                .frame(maxWidth: 440)
                            RadioStationsPlaying()
                        }
                    }
                    .padding(32)
                    .frame(maxWidth: 1200)
                    .frame(maxWidth: .infinity)
                }
                .background(Color(light: Color(hex: 0x3B3A37), dark: Color(hex: 0x1A1918)))
            )
        }
    }
}

/// Connections currently “on air”.
private struct RadioStationsPlaying: View {
    @Environment(SkinStore.self) private var store
    @Environment(\.skinTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(skin: "ON AIR").font(.system(size: 11, weight: .heavy)).tracking(3).foregroundStyle(RadioStyle.amber)
            ForEach(store.activeConnections.sorted { $0.downlink > $1.downlink }.prefix(12)) { connection in
                NavigationLink(value: RadioPage.connections) {
                    HStack {
                        Text(connection.hostName).lineLimit(1)
                        Spacer()
                        Text(connection.isDirect ? SkinL("DIRECT") : RadioScale.code(for: connection.outbound))
                            .foregroundStyle(RadioStyle.amber)
                        Text(SkinFormat.rate(connection.downlink)).frame(width: 90, alignment: .trailing)
                    }
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Color(hex: 0xE6E3DC))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RadioStyle.lcd, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .subscribesToConnections(store)
    }
}

// MARK: - Receipt (logs)

struct RadioReceipt: View {
    @Environment(SkinStore.self) private var store
    @Environment(SkinPreferences.self) private var preferences
    @Environment(\.skinTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @State private var paused: [SkinLogEntry]?

    var body: some View {
        @Bindable var preferences = preferences
        VStack(spacing: 0) {
            HStack {
                Button(SkinL("‹ Radio")) { dismiss() }
                Spacer()
                Text(SkinL("RECEIPT · %@", preferences.logLevel.name))
            }
            .font(.system(size: 11, weight: .heavy))
            .tracking(2)
            .foregroundStyle(theme.secondaryText)
            .buttonStyle(.plain)
            .padding(.horizontal, 24)
            .padding(.top, 12)
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(hex: 0x1A1A1A))
                .frame(height: 30)
                .padding(.horizontal, 24)
                .padding(.top, 14)
            RadioReceiptPaper(entriesOverride: paused)
                .padding(.horizontal, 40)
                .padding(.top, -14)
            Spacer(minLength: 12)
            HStack(spacing: 10) {
                Menu {
                    Picker(SkinL("Level"), selection: $preferences.logLevel) {
                        ForEach(SkinLogLevel.filterable) { Text(verbatim: $0.name).tag($0) }
                    }
                } label: {
                    RadioKeyLabel(title: SkinL("Level"))
                }
                .buttonStyle(.plain)
                RadioKey(title: paused == nil ? SkinL("Hold") : SkinL("Feed"), isOn: paused != nil) {
                    paused = paused == nil ? store.logs : nil
                }
                RadioKey(title: SkinL("Tear off"), isOn: false, dark: true) {
                    paused = nil
                    store.clearLogs()
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .background(theme.background)
        .toolbar(.hidden)
        .subscribesToLogs(store)
    }
}

private struct RadioKeyLabel: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.system(size: 13, weight: .heavy))
            .foregroundStyle(Color(hex: 0x1A1A1A))
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(hex: 0xF4F2ED))
                    .shadow(color: RadioStyle.keyShadow, radius: 0, y: 4)
            }
    }
}

/// Thermal-paper strip with the latest log lines.
struct RadioReceiptPaper: View {
    @Environment(SkinStore.self) private var store
    @Environment(SkinPreferences.self) private var preferences
    @Environment(\.skinConfiguration) private var configuration
    var maxLines = 400
    var entriesOverride: [SkinLogEntry]?

    var body: some View {
        let level = preferences.logLevel
        let entries = (entriesOverride ?? store.logs).filter { $0.level <= level }.suffix(maxLines)
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 3) {
                    Text(configuration.appName.uppercased()).font(.system(size: 13, weight: .bold, design: .monospaced)).tracking(3).frame(maxWidth: .infinity)
                    Text(Date.now.formatted(date: .abbreviated, time: .omitted)).font(.system(size: 11, design: .monospaced)).foregroundStyle(Color(hex: 0x6F6A60)).frame(maxWidth: .infinity)
                    dashed
                    ForEach(Array(entries)) { entry in
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(verbatim: String(entry.level.name.prefix(4)))
                                .fontWeight(.bold)
                                .foregroundStyle(entry.level <= .error ? Color(hex: 0xB91C1C) : (entry.level == .warn ? Color(hex: 0xC2410C) : Color(hex: 0x1A1A1A)))
                                .frame(width: 34, alignment: .leading)
                            Text(entry.plainMessage).foregroundStyle(Color(hex: 0x1A1A1A))
                        }
                        .font(.system(size: 11, design: .monospaced))
                    }
                    dashed
                    HStack { Text(skin: "TOTAL LINES"); Spacer(); Text(verbatim: "\(store.status.totalConnections)") }
                    HStack { Text(skin: "TOTAL TRAFFIC"); Spacer(); Text(SkinFormat.bytes(store.status.totalTraffic)) }
                }
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Color(hex: 0x1A1A1A))
                .textSelection(.enabled)
                .padding(20)
            }
            .defaultScrollAnchor(.bottom)
            .background(Color(hex: 0xFBFAF6))
            ZigZagEdge()
                .fill(Color(hex: 0xFBFAF6))
                .frame(height: 10)
        }
        .shadow(color: .black.opacity(0.12), radius: 10, y: 8)
    }

    private var dashed: some View {
        Line().stroke(style: StrokeStyle(lineWidth: 1, dash: [3, 3])).foregroundStyle(Color(hex: 0xB9B4A9)).frame(height: 1).padding(.vertical, 6)
    }
}

private struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: 0, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        }
    }
}

private struct ZigZagEdge: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            let tooth: CGFloat = 12
            path.move(to: .zero)
            var x: CGFloat = 0
            while x < rect.width {
                path.addLine(to: CGPoint(x: x + tooth / 2, y: rect.height))
                path.addLine(to: CGPoint(x: min(x + tooth, rect.width), y: 0))
                x += tooth
            }
            path.closeSubpath()
        }
    }
}
