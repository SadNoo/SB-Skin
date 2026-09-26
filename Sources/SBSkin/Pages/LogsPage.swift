import SBSkinShared
import SwiftUI

/// Log viewer: level filter, search, pause, clear, copy and share.
struct LogsPage: View {
    @Environment(SkinStore.self) private var store
    @Environment(SkinPreferences.self) private var preferences
    @Environment(\.skinTheme) private var theme
    @State private var search = ""
    @State private var pausedSnapshot: [SkinLogEntry]?
    @State private var confirmClear = false
    var monospaced = true

    private var visible: [SkinLogEntry] {
        let source = pausedSnapshot ?? store.logs
        let level = preferences.logLevel
        let terms = search.lowercased()
        return source.filter { entry in
            entry.level <= level && (terms.isEmpty || entry.plainMessage.lowercased().contains(terms))
        }
    }

    var body: some View {
        @Bindable var preferences = preferences
        let entries = visible
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(entries) { entry in
                        LogLine(entry: entry, monospaced: monospaced)
                            .id(entry.id)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .textSelection(.enabled)
            }
            .defaultScrollAnchor(.bottom)
            .overlay {
                if entries.isEmpty {
                    ContentUnavailableView(
                        store.logsLoaded ? SkinL("No logs") : SkinL("Loading logs…"),
                        systemImage: "list.bullet.rectangle",
                        description: Text(store.isRunning ? "" : SkinL("Logs appear while the service runs."))
                    )
                }
            }
            .onChange(of: entries.last?.id) { _, last in
                guard pausedSnapshot == nil, let last else { return }
                proxy.scrollTo(last, anchor: .bottom)
            }
        }
        .background(theme.background)
        .searchable(text: $search, prompt: Text(skin: "Search logs"))
        .navigationTitle(SkinL("Logs"))
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    pausedSnapshot = pausedSnapshot == nil ? store.logs : nil
                } label: {
                    Label(pausedSnapshot == nil ? SkinL("Pause") : SkinL("Resume"), systemImage: pausedSnapshot == nil ? "pause" : "play")
                }
                Menu {
                    Picker(SkinL("Level"), selection: $preferences.logLevel) {
                        ForEach(SkinLogLevel.filterable) { level in
                            Text(verbatim: level.name).tag(level)
                        }
                    }
                    Divider()
                    Button(SkinL("Copy"), systemImage: "doc.on.doc") {
                        copyToPasteboard(entries.map(\.plainMessage).joined(separator: "\n"))
                    }
                    ShareLink(item: entries.map(\.plainMessage).joined(separator: "\n")) {
                        Label(SkinL("Share"), systemImage: "square.and.arrow.up")
                    }
                    Divider()
                    Button(SkinL("Clear Logs"), systemImage: "trash", role: .destructive) {
                        confirmClear = true
                    }
                } label: {
                    Label(SkinL("Options"), systemImage: "ellipsis.circle")
                }
            }
        }
        .confirmationDialog(SkinL("Clear all logs?"), isPresented: $confirmClear, titleVisibility: .visible) {
            Button(SkinL("Clear Logs"), role: .destructive) {
                pausedSnapshot = nil
                store.clearLogs()
            }
        }
        .subscribesToLogs(store)
    }
}

struct LogLine: View {
    @Environment(\.skinTheme) private var theme
    let entry: SkinLogEntry
    var monospaced = true

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(verbatim: String(entry.level.name.prefix(4)))
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(levelColor)
                .frame(width: 34, alignment: .leading)
            Text(entry.plainMessage)
                .font(.system(size: 12, design: monospaced ? .monospaced : theme.textDesign))
                .foregroundStyle(entry.level <= .warn ? levelColor : theme.text)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 1)
    }

    private var levelColor: Color {
        switch entry.level {
        case .panic, .fatal, .error: SkinPalette.bad
        case .warn: SkinPalette.medium
        case .info: theme.accent
        case .debug, .trace: theme.secondaryText
        }
    }
}
