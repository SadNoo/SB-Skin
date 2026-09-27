import SkywaveShared
import SwiftUI

/// F · One Sentence. The whole state in one sentence; the underlined words are the controls.
struct SentenceSkin: View {
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        Group {
            #if os(macOS)
                SentenceShell(wide: true)
            #else
                SentenceShell(wide: sizeClass == .regular)
            #endif
        }
        .skinSheets(nodePicker: { group in AnyView(SentencePicker(initialGroup: group)) })
    }
}

enum SentenceTab: Hashable, CaseIterable {
    case now, records, tools, settings

    var title: String {
        switch self {
        case .now: SkinL("Now")
        case .records: SkinL("Records")
        case .tools: SkinL("Tools")
        case .settings: SkinL("Settings")
        }
    }
}

private struct SentenceShell: View {
    @Environment(SkinRouter.self) private var router
    @Environment(\.skinTheme) private var theme
    @Environment(\.skinConfiguration) private var configuration
    let wide: Bool
    @State private var tab: SentenceTab = .now

    var body: some View {
        SkinTabContainer(selection: $tab, tabs: SentenceTab.allCases, barHeight: 64) { tab in
            NavigationStack {
                switch tab {
                case .now: SentenceNow(wide: wide)
                case .records: SentenceRecords()
                case .tools:
                    if let tools = configuration.hostPages.tools { tools() } else { ConnectionsPage() }
                case .settings: MorePage()
                }
            }
        } bar: {
            HStack(spacing: 28) {
                ForEach(SentenceTab.allCases, id: \.self) { item in
                    Button {
                        tab = item
                    } label: {
                        Text(item.title)
                            .font(.system(size: 17, design: .serif))
                            .foregroundStyle(item == tab ? theme.text : theme.secondaryText)
                            .underline(item == tab, pattern: .solid)
                            .frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(item == tab ? .isSelected : [])
                }
                Spacer()
            }
            .padding(.horizontal, wide ? 48 : 28)
            .padding(.bottom, 12)
            .frame(maxWidth: wide ? 820 : .infinity, alignment: .leading)
            .background(theme.background.opacity(0.94))
        }
        .onChange(of: router.homeRequests) { _, _ in tab = .now }
    }
}

// MARK: - Now

private struct SentenceNow: View {
    @Environment(SkinStore.self) private var store
    @Environment(SkinRouter.self) private var router
    @Environment(SkinPreferences.self) private var preferences
    @Environment(\.skinTheme) private var theme
    let wide: Bool
    @State private var choosingMode = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(Date.now.formatted(.dateTime.month(.wide).day().weekday(.wide)).uppercased())
                    Spacer()
                    Button(store.activeProfile?.name ?? "") { router.sheet = .profiles }
                        .buttonStyle(.plain)
                }
                .font(.system(size: 12, weight: .semibold))
                .tracking(2)
                .foregroundStyle(theme.secondaryText)
                .padding(.top, 24)

                Text(headline)
                    .font(.system(size: wide ? 64 : 46, weight: .semibold, design: .serif))
                    .foregroundStyle(theme.text)
                    .padding(.top, wide ? 100 : 70)
                    .contentTransition(.opacity)
                    .animation(.smooth, value: headline)

                Text(sentence)
                    .font(.system(size: wide ? 38 : 30, design: .serif))
                    .lineSpacing(wide ? 14 : 10)
                    .foregroundStyle(theme.text)
                    .tint(theme.accent)
                    .padding(.top, 18)
                    .environment(\.openURL, OpenURLAction(handler: handleToken))
                    .confirmationDialog(SkinL("Route by"), isPresented: $choosingMode, titleVisibility: .visible) {
                        ForEach(store.clashModes, id: \.self) { mode in
                            Button(preferences.vocabulary.mode(mode)) { store.setClashMode(mode) }
                        }
                    }

                Rectangle().fill(theme.separator).frame(height: 1).padding(.top, wide ? 60 : 44)
                if store.isRunning {
                    HStack(alignment: .top) {
                        fact(SkinL("Downstream"), SkinFormat.rateParts(store.status.downlink))
                        fact(SkinL("Upstream"), SkinFormat.rateParts(store.status.uplink))
                        fact(SkinL("Round trip"), (store.currentNode.map { "\($0.delay)" } ?? "—", SkinL("ms")))
                    }
                    .padding(.top, 18)
                }
                Button {
                    store.toggleService()
                } label: {
                    HStack(spacing: 10) {
                        Circle().fill(store.phase.isActive ? SkinPalette.good : theme.secondaryText).frame(width: 10, height: 10)
                        Text(store.phase.isActive ? SkinL("Pause connection") : SkinL("Resume connection"))
                            .font(.system(size: 17, design: .serif))
                    }
                    .foregroundStyle(theme.text)
                    .padding(.horizontal, 18)
                    .frame(height: 46)
                    .overlay(Capsule().strokeBorder(theme.text.opacity(0.25)))
                }
                .buttonStyle(.plain)
                .disabled(store.phase == .unavailable || store.phase.isTransitioning)
                .padding(.top, 34)
            }
            .padding(.horizontal, wide ? 48 : 28)
            .frame(maxWidth: wide ? 820 : .infinity, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(theme.background)
        .toolbar(.hidden)
    }

    private var headline: String {
        guard store.hasProfiles else { return SkinL("Nothing set up yet.") }
        if store.setupRequirement != nil { return SkinL("One more step.") }
        switch store.phase {
        case .running:
            let grade = store.currentNode?.grade ?? .good
            return grade >= .good ? SkinL("The network is clear.") : SkinL("The network is a bit slow.")
        case .starting: return SkinL("Connecting…")
        case .reasserting: return SkinL("Reconnecting…")
        case .stopping: return SkinL("Pausing…")
        case .stopped: return SkinL("Paused.")
        case .unavailable: return SkinL("Nothing set up yet.")
        }
    }

    private var sentence: AttributedString {
        if store.needsGate {
            return SentenceBuilder.build(SkinL("Add a profile in %1$@ to begin."), tokens: [(SkinL("Settings"), "settings")])
        }
        if store.isRunning {
            let node = store.currentNode?.tag ?? "—"
            let mode = preferences.vocabulary.mode(store.clashMode)
            return SentenceBuilder.build(
                SkinL("Right now you're going through %1$@ with %2$@, and have used %3$@."),
                tokens: [(node, "node"), (mode, "mode"), (SkinFormat.bytes(store.status.totalTraffic), nil)]
            )
        }
        return SentenceBuilder.build(
            SkinL("Your traffic goes out directly. %1$@ when you want the proxy back."),
            tokens: [(SkinL("Resume"), "start")]
        )
    }

    private func handleToken(_ url: URL) -> OpenURLAction.Result {
        guard url.scheme == SentenceBuilder.scheme else { return .systemAction }
        switch url.host {
        case "node": router.showNodes()
        case "mode": choosingMode = true
        case "start": store.startService()
        case "settings": router.sheet = .more
        case "setup": store.performSetup()
        default: break
        }
        return .handled
    }

    private func fact(_ title: String, _ parts: (value: String, unit: String)) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 12, design: .serif)).italic().foregroundStyle(theme.secondaryText)
            Text(parts.value).font(.system(size: wide ? 30 : 22, design: .serif)).monospacedDigit().foregroundStyle(theme.text).contentTransition(.numericText())
            Text(parts.unit).font(.system(size: 12, design: .serif)).foregroundStyle(theme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Builds a sentence where some words are tappable links.
enum SentenceBuilder {
    static let scheme = "skywave-token"

    /// `format` uses positional placeholders (`%1$@`, `%2$@`…). A token with an id becomes a
    /// dotted-underlined link `skywave-token://<id>`.
    static func build(_ format: String, tokens: [(text: String, id: String?)]) -> AttributedString {
        var result = AttributedString()
        var remaining = Substring(format)
        while let range = remaining.range(of: #"%(\d+)\$@"#, options: .regularExpression) {
            result += AttributedString(String(remaining[..<range.lowerBound]))
            let marker = remaining[range]
            let index = Int(marker.dropFirst().prefix { $0.isNumber }) ?? 1
            if tokens.indices.contains(index - 1) {
                let token = tokens[index - 1]
                var piece = AttributedString(token.text)
                if let id = token.id {
                    piece.link = URL(string: "\(scheme)://\(id)")
                    piece.underlineStyle = Text.LineStyle(pattern: .dot)
                }
                result += piece
            }
            remaining = remaining[range.upperBound...]
        }
        result += AttributedString(String(remaining))
        return result
    }
}

// MARK: - Picker: complete the sentence

struct SentencePicker: View {
    @Environment(SkinStore.self) private var store
    @Environment(SkinPreferences.self) private var preferences
    @Environment(\.skinTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    var initialGroup: String?
    @State private var groupTag: String?

    var body: some View {
        let selectable = store.groups.filter(\.selectable)
        let group = store.group(groupTag ?? initialGroup ?? "") ?? store.primaryGroup
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Button(SkinL("Cancel")) { dismiss() }
                        .foregroundStyle(theme.secondaryText)
                    Spacer()
                    Button(SkinL("Test again")) { if let group { store.urlTest(group.tag) } }
                        .foregroundStyle(theme.accent)
                        .disabled(group.map { store.testingGroups.contains($0.tag) } ?? true)
                }
                .font(.system(size: 17, design: .serif))
                .buttonStyle(.plain)
                .padding(.top, 20)

                (Text(skin: "Right now you're going through") + Text(verbatim: " ") + Text(verbatim: group.map { store.resolvedNode(in: $0).node?.tag ?? $0.selected } ?? "—").foregroundColor(theme.accent).underline())
                    .font(.system(size: 30, design: .serif))
                    .foregroundStyle(theme.text)
                    .padding(.top, 28)

                if selectable.count > 1 {
                    HStack(spacing: 22) {
                        ForEach(selectable) { item in
                            Button(item.tag) { groupTag = item.tag }
                                .font(.system(size: 16, weight: item.tag == group?.tag ? .bold : .regular))
                                .foregroundStyle(item.tag == group?.tag ? theme.text : theme.secondaryText)
                                .underline(item.tag == group?.tag)
                                .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 22)
                }

                if let group {
                    VStack(spacing: 0) {
                        ForEach(group.items) { item in
                            let selected = item.tag == group.selected
                            Button {
                                store.select(item.tag, in: group.tag)
                                dismiss()
                            } label: {
                                HStack(alignment: .firstTextBaseline, spacing: 12) {
                                    Text(verbatim: selected ? "●" : "").font(.system(size: 13)).foregroundStyle(theme.accent).frame(width: 14)
                                    Text(item.tag).font(.system(size: 26, design: .serif)).foregroundStyle(item.grade == .unreachable ? theme.secondaryText : theme.text).lineLimit(1)
                                    Spacer()
                                    Text(item.delay > 0 && item.delay != .max ? "\(item.delay)" : "—").font(.system(size: 20, design: .serif)).monospacedDigit().foregroundStyle(theme.text)
                                    Text(item.grade == .unreachable ? SkinL("no route") : SkinL("ms")).font(.system(size: 12, design: .serif)).foregroundStyle(theme.secondaryText).frame(width: 52, alignment: .leading)
                                }
                                .padding(.vertical, 16)
                                .overlay(alignment: .top) { Rectangle().fill(theme.separator).frame(height: 1) }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .disabled(!group.selectable)
                        }
                    }
                    .padding(.top, 20)
                }
            }
            .padding(.horizontal, 28)
            .frame(maxWidth: 820, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(theme.background)
        .fontDesign(.serif)
    }
}

// MARK: - Records: recent connections as sentences, logs below

private struct SentenceRecords: View {
    @Environment(SkinStore.self) private var store
    @Environment(\.skinTheme) private var theme

    var body: some View {
        List {
            Section {
                ForEach(store.connections.sorted { $0.createdAt > $1.createdAt }.prefix(40)) { connection in
                    NavigationLink {
                        ConnectionDetailPage(connectionID: connection.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(connection.createdAt.formatted(date: .omitted, time: .shortened))
                                .font(.system(size: 12, design: .serif)).italic()
                                .foregroundStyle(theme.secondaryText)
                            Text(connection.isDirect
                                ? SkinL("%@ went directly.", connection.hostName)
                                : SkinL("%1$@ went through %2$@.", connection.hostName, connection.outbound))
                                .font(.system(size: 18, design: .serif))
                                .foregroundStyle(connection.isActive ? theme.text : theme.secondaryText)
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(theme.background)
                }
            } header: {
                HStack {
                    Text(skin: "Connections")
                    Spacer()
                    NavigationLink(SkinL("Logs")) { LogsPage() }
                }
                .font(.system(size: 13, design: .serif))
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(theme.background)
        .navigationTitle(SkinL("Records"))
        .subscribesToConnections(store)
    }
}
