import SkywaveShared
import SwiftUI
import WidgetKit

// MARK: - Status widget (home screen, lock screen, desktop)

/// Home Screen / Lock Screen / macOS desktop widget showing the running state, node and speed.
///
/// Add it to the host's widget extension:
/// ```swift
/// @main struct Widgets: WidgetBundle {
///     var body: some Widget {
///         ServiceToggleControl()      // upstream control
///         SkinStatusWidget()
///         SkinLiveActivityWidget()    // iOS
///     }
/// }
/// ```
public struct SkinStatusWidget: Widget {
    public static let kind = "skywave.status"

    public init() {}

    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: SnapshotProvider()) { entry in
            StatusWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetBackground(skin: entry.snapshot.skin)
                }
        }
        .configurationDisplayName(WidgetL("Connection"))
        .description(WidgetL("Current node, speed and how long you've been connected."))
        .supportedFamilies(Self.families)
    }

    private static var families: [WidgetFamily] {
        #if os(iOS)
            [.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline]
        #else
            [.systemSmall, .systemMedium]
        #endif
    }
}

struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: SkinWidgetSnapshot
}

struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        let snapshot = context.isPreview ? .placeholder : (SkinSharedStorage.readSnapshot() ?? .placeholder)
        completion(SnapshotEntry(date: .now, snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        let snapshot = SkinSharedStorage.readSnapshot() ?? SkinWidgetSnapshot()
        let entry = SnapshotEntry(date: .now, snapshot: snapshot)
        // The app reloads timelines when state changes; this is only a safety net.
        completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(15 * 60))))
    }
}

struct StatusWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SnapshotEntry

    private var snapshot: SkinWidgetSnapshot { entry.snapshot }

    var body: some View {
        switch family {
        case .systemMedium: medium
        #if os(iOS)
            case .accessoryCircular: circular
            case .accessoryRectangular: rectangular
            case .accessoryInline: inline
        #endif
        default: small
        }
    }

    private var tint: Color { snapshot.skin.accent }

    /// Tapping a stopped widget starts the service; a running one opens the app.
    private var tapURL: URL? {
        (snapshot.isRunning ? SkinDeepLink.home : SkinDeepLink.start).url(scheme: snapshot.deepLinkScheme)
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "power")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(snapshot.isRunning ? .white : .secondary)
                    .frame(width: 34, height: 34)
                    .background(snapshot.isRunning ? tint : Color.secondary.opacity(0.18), in: Circle())
                Spacer()
                if snapshot.isRunning {
                    Text(snapshot.vocabulary.latency(snapshot.nodeDelay))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(LatencyGrade(delay: snapshot.nodeDelay).color)
                }
            }
            Spacer(minLength: 0)
            Text(snapshot.isRunning ? WidgetL("Connected") : WidgetL("Not connected"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(snapshot.isRunning ? snapshot.nodeTag : snapshot.profileName)
                .font(.headline.weight(.bold))
                .lineLimit(2)
                .minimumScaleFactor(0.7)
            if snapshot.isRunning, let since = snapshot.connectedSince {
                Text(since, style: .timer)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .widgetURL(tapURL)
    }

    private var medium: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(snapshot.isRunning ? WidgetL("Connected") : WidgetL("Not connected"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(snapshot.isRunning ? snapshot.nodeTag : snapshot.profileName)
                    .font(.title3.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(verbatim: [snapshot.vocabulary.mode(snapshot.mode), snapshot.profileName].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if snapshot.isRunning {
                    Text(verbatim: "↓ \(SkinFormat.rate(snapshot.downlink))  ↑ \(SkinFormat.rate(snapshot.uplink))")
                        .font(.caption.weight(.semibold).monospacedDigit())
                }
            }
            if snapshot.isRunning {
                WidgetSparkline(values: snapshot.downlinkHistory, color: tint)
                    .frame(maxWidth: .infinity)
            } else {
                Image(systemName: "power")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 64, height: 64)
                    .background(tint, in: Circle())
                    .frame(maxWidth: .infinity)
            }
        }
        .widgetURL(tapURL)
    }

    #if os(iOS)
        private var circular: some View {
            Gauge(value: Double(LatencyGrade(delay: snapshot.nodeDelay).bars), in: 0 ... 3) {
                Image(systemName: "network")
            } currentValueLabel: {
                Text(verbatim: snapshot.isRunning && snapshot.nodeDelay > 0 ? "\(snapshot.nodeDelay)" : "—")
                    .font(.system(.body, design: .rounded).weight(.bold))
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .widgetURL(tapURL)
        }

        private var rectangular: some View {
            VStack(alignment: .leading, spacing: 1) {
                Text(snapshot.isRunning ? snapshot.nodeTag : WidgetL("Not connected"))
                    .font(.headline)
                    .lineLimit(1)
                if snapshot.isRunning {
                    Text(verbatim: "↓ \(SkinFormat.rate(snapshot.downlink)) ↑ \(SkinFormat.rate(snapshot.uplink))")
                        .font(.caption.monospacedDigit())
                    if let since = snapshot.connectedSince {
                        Text(since, style: .timer).font(.caption.monospacedDigit())
                    }
                } else {
                    Text(snapshot.profileName).font(.caption)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .widgetURL(tapURL)
        }

        private var inline: some View {
            Text(verbatim: snapshot.isRunning ? "\(snapshot.nodeTag) · \(snapshot.vocabulary.latency(snapshot.nodeDelay))" : WidgetL("Not connected"))
                .widgetURL(tapURL)
        }
    #endif
}

struct WidgetBackground: View {
    let skin: SkinID

    var body: some View {
        switch skin {
        case .instrument: Color(red: 0.04, green: 0.05, blue: 0.06)
        case .sentence: Color(light: Color(red: 0.95, green: 0.93, blue: 0.9), dark: Color(red: 0.09, green: 0.08, blue: 0.07))
        case .radio: Color(light: Color(red: 0.9, green: 0.89, blue: 0.86), dark: Color(red: 0.16, green: 0.16, blue: 0.15))
        default: Rectangle().fill(.fill.tertiary)
        }
    }
}

struct WidgetSparkline: View {
    let values: [Double]
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            let top = max(values.max() ?? 1, 1)
            let points = values.enumerated().map { index, value in
                CGPoint(
                    x: proxy.size.width * CGFloat(index) / CGFloat(max(values.count - 1, 1)),
                    y: proxy.size.height * (1 - CGFloat(value / top) * 0.9)
                )
            }
            ZStack {
                Path { path in
                    guard let first = points.first, let last = points.last else { return }
                    path.move(to: CGPoint(x: first.x, y: proxy.size.height))
                    points.forEach { path.addLine(to: $0) }
                    path.addLine(to: CGPoint(x: last.x, y: proxy.size.height))
                    path.closeSubpath()
                }
                .fill(color.opacity(0.18))
                Path { path in
                    guard let first = points.first else { return }
                    path.move(to: first)
                    points.dropFirst().forEach { path.addLine(to: $0) }
                }
                .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
        }
    }
}

func WidgetL(_ key: String) -> String {
    String(localized: String.LocalizationValue(key), bundle: .module)
}

// MARK: - Live Activity (iOS)

#if os(iOS)
    import ActivityKit

    /// Lock Screen and Dynamic Island presentation of the running service.
    public struct SkinLiveActivityWidget: Widget {
        public init() {}

        public var body: some WidgetConfiguration {
            ActivityConfiguration(for: SkinActivityAttributes.self) { context in
                LiveActivityLockScreen(attributes: context.attributes, state: context.state)
                    .activityBackgroundTint(Color.black.opacity(0.55))
                    .activitySystemActionForegroundColor(.white)
            } dynamicIsland: { context in
                let state = context.state
                let attributes = context.attributes
                let grade = LatencyGrade(delay: state.nodeDelay)
                return DynamicIsland {
                    DynamicIslandExpandedRegion(.leading) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(attributes.vocabulary.mode(state.mode))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(state.nodeTag)
                                .font(.headline)
                                .lineLimit(1)
                        }
                    }
                    DynamicIslandExpandedRegion(.trailing) {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(attributes.vocabulary.latency(state.nodeDelay))
                                .font(.caption)
                                .foregroundStyle(grade.color)
                            Text(verbatim: "↓ \(SkinFormat.rate(state.downlink))")
                                .font(.subheadline.weight(.semibold).monospacedDigit())
                                .foregroundStyle(attributes.skin.accent)
                        }
                    }
                    DynamicIslandExpandedRegion(.bottom) {
                        VStack(spacing: 10) {
                            WidgetSparkline(values: state.downlinkHistory, color: attributes.skin.accent)
                                .frame(height: 24)
                            HStack(spacing: 8) {
                                ActivityLinkButton(title: WidgetL("Change Node"), link: .nodes, scheme: attributes.deepLinkScheme)
                                ActivityLinkButton(title: WidgetL("Disconnect"), link: .stop, scheme: attributes.deepLinkScheme, destructive: true)
                            }
                        }
                    }
                } compactLeading: {
                    Circle()
                        .fill(state.isRunning ? SkinPalette.good : Color.orange)
                        .frame(width: 8, height: 8)
                } compactTrailing: {
                    Text(verbatim: Self.compactLabel(state))
                        .font(.caption2.weight(.bold).monospacedDigit())
                        .foregroundStyle(attributes.skin.accent)
                } minimal: {
                    Circle()
                        .fill(state.isRunning ? SkinPalette.good : Color.orange)
                        .frame(width: 8, height: 8)
                }
                .widgetURL(SkinDeepLink.home.url(scheme: attributes.deepLinkScheme))
                .keylineTint(attributes.skin.accent)
            }
        }

        static func compactLabel(_ state: SkinActivityAttributes.ContentState) -> String {
            let letters = state.nodeTag.unicodeScalars.filter { $0.isASCII && CharacterSet.letters.contains($0) }
            let short = letters.isEmpty ? String(state.nodeTag.prefix(2)) : String(String.UnicodeScalarView(letters).prefix(2)).uppercased()
            return state.nodeDelay > 0 && state.nodeDelay != .max ? "\(short) \(state.nodeDelay)" : short
        }
    }

    struct ActivityLinkButton: View {
        let title: String
        let link: SkinDeepLink
        let scheme: String?
        var destructive = false

        var body: some View {
            if let url = link.url(scheme: scheme) {
                Link(destination: url) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(Color.white.opacity(0.14), in: Capsule())
                        .foregroundStyle(destructive ? Color.red : Color.white)
                }
            }
        }
    }

    struct LiveActivityLockScreen: View {
        let attributes: SkinActivityAttributes
        let state: SkinActivityAttributes.ContentState

        var body: some View {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "network")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(attributes.skin.accent, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(WidgetL("Connected via"))
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                        Text(state.nodeTag)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(attributes.vocabulary.mode(state.mode))
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                        if let since = state.connectedSince {
                            Text(since, style: .timer)
                                .font(.headline.monospacedDigit())
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }
                WidgetSparkline(values: state.downlinkHistory, color: attributes.skin.accent)
                    .frame(height: 30)
                HStack {
                    Text(verbatim: "↓ \(SkinFormat.rate(state.downlink))   ↑ \(SkinFormat.rate(state.uplink))")
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.85))
                    Spacer()
                    if let url = SkinDeepLink.nodes.url(scheme: attributes.deepLinkScheme) {
                        Link(destination: url) {
                            Text(WidgetL("Change Node"))
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 12)
                                .frame(height: 28)
                                .background(Color.white.opacity(0.16), in: Capsule())
                                .foregroundStyle(.white)
                        }
                    }
                }
            }
            .padding(16)
        }
    }
#endif
