import Foundation

/// Tiles available on the Bento home. Covers every upstream dashboard card
/// (upload, download, status, connections, system proxy, Clash mode, profile) plus a few
/// shortcuts that already exist elsewhere in the app.
public enum BentoModuleID: String, CaseIterable, Codable, Sendable, Identifiable {
    case download
    case power
    case node
    case mode
    case upload
    case stats
    case totals
    case systemProxy
    case profile
    case groups
    case connections
    case logs

    public var id: String { rawValue }

    public static let defaultOrder: [BentoModuleID] = [.download, .power, .node, .mode, .upload, .stats]

    var title: String {
        switch self {
        case .download: SkinL("Download")
        case .power: SkinL("Connection")
        case .node: SkinL("Node")
        case .mode: SkinL("Mode")
        case .upload: SkinL("Upload")
        case .stats: SkinL("Status")
        case .totals: SkinL("Traffic")
        case .systemProxy: SkinL("System Proxy")
        case .profile: SkinL("Profile")
        case .groups: SkinL("Outbound Groups")
        case .connections: SkinL("Connections")
        case .logs: SkinL("Logs")
        }
    }

    var symbol: String {
        switch self {
        case .download: "arrow.down"
        case .power: "power"
        case .node: "point.3.connected.trianglepath.dotted"
        case .mode: "arrow.triangle.branch"
        case .upload: "arrow.up"
        case .stats: "memorychip"
        case .totals: "chart.bar"
        case .systemProxy: "network"
        case .profile: "doc.text"
        case .groups: "square.grid.3x3"
        case .connections: "arrow.left.arrow.right"
        case .logs: "list.bullet.rectangle"
        }
    }
}
