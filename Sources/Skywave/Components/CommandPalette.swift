import SkywaveShared
import SwiftUI

/// ⌘K palette available in every skin (Mac, and iPad with a keyboard).
/// Type “japan”, “global”, “test”, “logs”… and press Return.
struct CommandPalette: View {
    @Environment(SkinStore.self) private var store
    @Environment(SkinPreferences.self) private var preferences
    @Environment(SkinRouter.self) private var router
    @Environment(\.skinTheme) private var theme
    @Binding var isPresented: Bool
    @State private var query = ""
    @State private var highlighted = 0
    @FocusState private var focused: Bool

    struct Command: Identifiable {
        let id: String
        let section: String
        let title: String
        let detail: String
        let symbol: String
        let action: @MainActor () -> Void
    }

    private var commands: [Command] {
        var list: [Command] = []
        let vocabulary = preferences.vocabulary
        let service = SkinL("Service")
        list.append(Command(
            id: "service.toggle", section: service,
            title: store.phase.isActive ? SkinL("Stop service") : SkinL("Start service"),
            detail: store.phase.label, symbol: "power"
        ) { store.toggleService() })

        for group in store.groups where group.selectable {
            for item in group.items where item.tag != group.selected {
                list.append(Command(
                    id: "node.\(group.tag).\(item.tag)", section: SkinL("Nodes"),
                    title: SkinL("Use %@", item.tag), detail: "\(group.tag) · \(vocabulary.latency(item.delay))",
                    symbol: "point.3.connected.trianglepath.dotted"
                ) { store.select(item.tag, in: group.tag) })
            }
        }
        for mode in store.clashModes where mode != store.clashMode {
            list.append(Command(
                id: "mode.\(mode)", section: SkinL("Mode"),
                title: SkinL("Switch to %@", vocabulary.mode(mode)), detail: mode, symbol: "arrow.triangle.branch"
            ) { store.setClashMode(mode) })
        }
        list.append(Command(id: "test", section: SkinL("Actions"), title: SkinL("Test all latencies"), detail: "", symbol: "bolt") { store.urlTestAll() })
        list.append(Command(id: "nodes", section: SkinL("Actions"), title: SkinL("Open outbound groups"), detail: "", symbol: "square.grid.3x3") { router.sheet = .nodes })
        list.append(Command(id: "connections", section: SkinL("Actions"), title: SkinL("Open connections"), detail: "", symbol: "arrow.left.arrow.right") { router.sheet = .connections })
        list.append(Command(id: "logs", section: SkinL("Actions"), title: SkinL("Open logs"), detail: "", symbol: "list.bullet.rectangle") { router.sheet = .logs })
        for profile in store.profiles where profile.id != store.selectedProfileID {
            list.append(Command(id: "profile.\(profile.id)", section: SkinL("Profiles"), title: SkinL("Switch to profile %@", profile.name), detail: "", symbol: "doc.text") { store.selectProfile(profile.id) })
        }
        for skin in SkinID.allCases where skin != preferences.skin {
            list.append(Command(id: "skin.\(skin.rawValue)", section: SkinL("Skins"), title: SkinL("Use skin %@", skin.displayName), detail: skin.tagline, symbol: skin.symbol) { preferences.skin = skin })
        }
        return list
    }

    private var results: [Command] {
        let terms = query.lowercased().split(separator: " ").map(String.init)
        guard !terms.isEmpty else { return Array(commands.prefix(12)) }
        return commands.filter { command in
            let haystack = "\(command.title) \(command.detail) \(command.section) \(command.id)".lowercased()
            return terms.allSatisfy { haystack.contains($0) }
        }
    }

    var body: some View {
        let results = results
        ZStack(alignment: .top) {
            Color.black.opacity(0.18)
                .ignoresSafeArea()
                .onTapGesture { isPresented = false }
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField(SkinL("Type a command, node or mode"), text: $query)
                        .textFieldStyle(.plain)
                        .font(.title3)
                        .focused($focused)
                        .onSubmit { run(results) }
                        .onKeyPress(.downArrow) { highlighted = min(highlighted + 1, max(results.count - 1, 0)); return .handled }
                        .onKeyPress(.upArrow) { highlighted = max(highlighted - 1, 0); return .handled }
                        .onKeyPress(.escape) { isPresented = false; return .handled }
                    Text(verbatim: "esc").font(.caption).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 18)
                .frame(height: 56)
                Divider()
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(Array(results.enumerated()), id: \.element.id) { index, command in
                                Button {
                                    command.action()
                                    isPresented = false
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: command.symbol).frame(width: 22)
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(command.title).lineLimit(1)
                                            if !command.detail.isEmpty {
                                                Text(command.detail).font(.caption).opacity(0.7).lineLimit(1)
                                            }
                                        }
                                        Spacer()
                                        Text(command.section).font(.caption).opacity(0.6)
                                    }
                                    .padding(.horizontal, 12)
                                    .frame(minHeight: 44)
                                    .foregroundStyle(index == highlighted ? theme.onAccent : theme.text)
                                    .background(index == highlighted ? theme.accent : .clear, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .id(index)
                            }
                            if results.isEmpty {
                                Text(skin: "No matching commands")
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, minHeight: 60)
                            }
                        }
                        .padding(8)
                    }
                    .frame(maxHeight: 380)
                    .onChange(of: highlighted) { _, value in proxy.scrollTo(value) }
                }
            }
            .frame(maxWidth: 640)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: .black.opacity(0.25), radius: 30, y: 16)
            .padding(.horizontal, 20)
            .padding(.top, 80)
        }
        .onAppear { focused = true }
        .onChange(of: query) { _, _ in highlighted = 0 }
    }

    private func run(_ results: [Command]) {
        guard results.indices.contains(highlighted) else { return }
        results[highlighted].action()
        isPresented = false
    }
}
