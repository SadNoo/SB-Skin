import SBSkinShared
import SwiftUI

enum ConnectionFilter: String, CaseIterable, Identifiable {
    case active, closed, all
    var id: String { rawValue }
    var title: String {
        switch self {
        case .active: SkinL("Active")
        case .closed: SkinL("Closed")
        case .all: SkinL("All")
        }
    }
}

enum ConnectionSortOrder: String, CaseIterable, Identifiable {
    case date, speed, total
    var id: String { rawValue }
    var title: String {
        switch self {
        case .date: SkinL("Newest")
        case .speed: SkinL("Speed")
        case .total: SkinL("Total traffic")
        }
    }
}

/// Filtering, sorting and search shared by every connection list.
struct ConnectionQuery {
    var filter: ConnectionFilter = .active
    var sort: ConnectionSortOrder = .date
    var search = ""

    func apply(_ connections: [SkinConnection]) -> [SkinConnection] {
        var result = connections.filter { connection in
            switch filter {
            case .active: connection.isActive
            case .closed: !connection.isActive
            case .all: true
            }
        }
        let terms = search.lowercased().split(separator: " ").map(String.init)
        if !terms.isEmpty {
            result = result.filter { connection in
                let haystack = [connection.displayDestination, connection.domain, connection.destination, connection.rule, connection.outbound, connection.inbound, connection.network, connection.processName ?? ""]
                    .joined(separator: " ").lowercased()
                return terms.allSatisfy { haystack.contains($0) }
            }
        }
        switch sort {
        case .date: result.sort { $0.createdAt > $1.createdAt }
        case .speed: result.sort { $0.uplink + $0.downlink > $1.uplink + $1.downlink }
        case .total: result.sort { $0.totalBytes > $1.totalBytes }
        }
        return result
    }
}

/// Live connection list with search, filter, sort and close. Drill in for the journey view.
struct ConnectionsPage: View {
    @Environment(SkinStore.self) private var store
    @Environment(\.skinTheme) private var theme
    @State private var query = ConnectionQuery()
    @State private var confirmCloseAll = false

    var body: some View {
        let rows = query.apply(store.connections)
        List {
            if !store.connectionsLoaded {
                ProgressView().frame(maxWidth: .infinity).listRowBackground(Color.clear)
            } else if rows.isEmpty {
                ContentUnavailableView(
                    SkinL("No connections"),
                    systemImage: "arrow.left.arrow.right",
                    description: Text(store.isRunning ? SkinL("Nothing matches right now.") : SkinL("Start the service to see live connections."))
                )
                .listRowBackground(Color.clear)
            }
            ForEach(rows) { connection in
                NavigationLink(value: connection.id) {
                    ConnectionRow(connection: connection)
                }
                .listRowBackground(theme.surface)
                .swipeActions {
                    if connection.isActive {
                        Button(SkinL("Close"), role: .destructive) { store.close(connection) }
                    }
                }
                .contextMenu {
                    if connection.isActive {
                        Button(SkinL("Close Connection"), systemImage: "xmark.circle", role: .destructive) { store.close(connection) }
                    }
                    Button(SkinL("Copy Destination"), systemImage: "doc.on.doc") {
                        copyToPasteboard(connection.displayDestination)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(theme.background)
        .searchable(text: $query.search, prompt: Text(skin: "Search destination, rule, node"))
        .navigationTitle(SkinL("Connections"))
        .navigationDestination(for: String.self) { id in
            ConnectionDetailPage(connectionID: id)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Picker(SkinL("Show"), selection: $query.filter) {
                        ForEach(ConnectionFilter.allCases) { Text($0.title).tag($0) }
                    }
                    Picker(SkinL("Sort By"), selection: $query.sort) {
                        ForEach(ConnectionSortOrder.allCases) { Text($0.title).tag($0) }
                    }
                    Divider()
                    Button(SkinL("Close All Connections"), systemImage: "xmark.circle", role: .destructive) {
                        confirmCloseAll = true
                    }
                    .disabled(store.activeConnections.isEmpty)
                } label: {
                    Label(SkinL("Options"), systemImage: "line.3.horizontal.decrease.circle")
                }
            }
        }
        .confirmationDialog(SkinL("Close all connections?"), isPresented: $confirmCloseAll, titleVisibility: .visible) {
            Button(SkinL("Close All"), role: .destructive) { store.closeAllConnections() }
        }
        .subscribesToConnections(store)
    }
}

/// One connection: destination, route and live speed.
struct ConnectionRow: View {
    @Environment(\.skinTheme) private var theme
    let connection: SkinConnection

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(connection.displayDestination)
                    .font(theme.font(.subheadline, weight: .semibold))
                    .foregroundStyle(connection.isActive ? theme.text : theme.secondaryText)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(verbatim: connection.network.uppercased())
                    if !connection.protocolName.isEmpty {
                        Text(verbatim: connection.protocolName)
                    }
                    if let name = connection.processName {
                        Text(verbatim: name)
                    }
                }
                .font(.caption2.weight(.medium))
                .foregroundStyle(theme.secondaryText)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 3) {
                RoutePill(connection: connection)
                if connection.isActive {
                    Text(verbatim: "↓ \(SkinFormat.rate(connection.downlink))")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(theme.secondaryText)
                } else {
                    Text(verbatim: SkinFormat.bytes(connection.totalBytes))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(theme.secondaryText)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

/// `→ Hong Kong 02` or `Direct`, colored by whether it went through a proxy.
struct RoutePill: View {
    @Environment(\.skinTheme) private var theme
    let connection: SkinConnection

    var body: some View {
        Text(connection.isDirect ? SkinL("Direct") : connection.outbound)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .foregroundStyle(connection.isDirect ? SkinPalette.good : theme.accent)
            .background((connection.isDirect ? SkinPalette.good : theme.accent).opacity(0.12), in: Capsule())
    }
}

func copyToPasteboard(_ text: String) {
    #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    #else
        UIPasteboard.general.string = text
    #endif
}
