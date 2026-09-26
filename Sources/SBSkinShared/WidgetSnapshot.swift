import Foundation

/// Everything a widget, Live Activity or control needs, written by the app into the
/// shared App Group so extensions can render without talking to the core.
public struct SkinWidgetSnapshot: Codable, Sendable, Equatable {
    public struct Node: Codable, Sendable, Equatable, Identifiable {
        public var tag: String
        public var delay: UInt16
        public var id: String { tag }

        public init(tag: String, delay: UInt16) {
            self.tag = tag
            self.delay = delay
        }
    }

    public var isRunning: Bool
    public var connectedSince: Date?
    public var profileName: String
    public var groupTag: String
    public var nodeTag: String
    public var nodeDelay: UInt16
    public var mode: String
    public var uplink: Int64
    public var downlink: Int64
    public var uplinkTotal: Int64
    public var downlinkTotal: Int64
    public var connections: Int
    public var memory: Int64
    public var downlinkHistory: [Double]
    public var favorites: [Node]
    public var skin: SkinID
    public var vocabulary: SkinVocabulary
    public var deepLinkScheme: String?
    public var updatedAt: Date

    public init(
        isRunning: Bool = false,
        connectedSince: Date? = nil,
        profileName: String = "",
        groupTag: String = "",
        nodeTag: String = "",
        nodeDelay: UInt16 = 0,
        mode: String = "",
        uplink: Int64 = 0,
        downlink: Int64 = 0,
        uplinkTotal: Int64 = 0,
        downlinkTotal: Int64 = 0,
        connections: Int = 0,
        memory: Int64 = 0,
        downlinkHistory: [Double] = [],
        favorites: [Node] = [],
        skin: SkinID = .default,
        vocabulary: SkinVocabulary = .everyday,
        deepLinkScheme: String? = nil,
        updatedAt: Date = .now
    ) {
        self.isRunning = isRunning
        self.connectedSince = connectedSince
        self.profileName = profileName
        self.groupTag = groupTag
        self.nodeTag = nodeTag
        self.nodeDelay = nodeDelay
        self.mode = mode
        self.uplink = uplink
        self.downlink = downlink
        self.uplinkTotal = uplinkTotal
        self.downlinkTotal = downlinkTotal
        self.connections = connections
        self.memory = memory
        self.downlinkHistory = downlinkHistory
        self.favorites = favorites
        self.skin = skin
        self.vocabulary = vocabulary
        self.deepLinkScheme = deepLinkScheme
        self.updatedAt = updatedAt
    }

    /// Sample content for widget galleries and previews.
    public static let placeholder = SkinWidgetSnapshot(
        isRunning: true,
        connectedSince: Date(timeIntervalSinceNow: -6137),
        profileName: "My Subscription",
        groupTag: "Proxy",
        nodeTag: "Hong Kong 02",
        nodeDelay: 186,
        mode: "rule",
        uplink: 1_258_291,
        downlink: 19_503_513,
        uplinkTotal: 327_155_712,
        downlinkTotal: 5_153_960_755,
        connections: 99,
        memory: 40_055_603,
        downlinkHistory: [4, 6, 5, 9, 8, 12, 10, 15, 11, 16, 13, 18, 15, 19, 14, 17, 18, 20, 16, 19],
        favorites: [
            Node(tag: "Hong Kong 02", delay: 186),
            Node(tag: "Hong Kong 01", delay: 172),
            Node(tag: "Japan 01", delay: 264),
        ]
    )
}

/// Reads and writes shared state in the host's App Group.
public enum SkinSharedStorage {
    private static let snapshotKey = "sbskin.widget.snapshot"

    /// Defaults to the `AppGroupIdentifier` Info.plist key the upstream client already defines
    /// in the app and in every extension. Hosts may override it at launch.
    nonisolated(unsafe) public static var appGroupIdentifier: String? =
        Bundle.main.object(forInfoDictionaryKey: "AppGroupIdentifier") as? String

    public static var defaults: UserDefaults {
        if let group = appGroupIdentifier, let shared = UserDefaults(suiteName: group) {
            return shared
        }
        return .standard
    }

    public static func readSnapshot() -> SkinWidgetSnapshot? {
        guard let data = defaults.data(forKey: snapshotKey) else { return nil }
        return try? JSONDecoder().decode(SkinWidgetSnapshot.self, from: data)
    }

    public static func writeSnapshot(_ snapshot: SkinWidgetSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: snapshotKey)
    }
}

/// URLs that widgets and Live Activities use to drive the app.
/// Format: `<scheme>://sbskin/<action>`; the scheme is the host app's own URL scheme.
public enum SkinDeepLink: String, Sendable, CaseIterable {
    case home
    case nodes
    case activity
    case start
    case stop
    case toggle

    public static let host = "sbskin"

    public func url(scheme: String?) -> URL? {
        guard let scheme, !scheme.isEmpty else { return nil }
        return URL(string: "\(scheme)://\(Self.host)/\(rawValue)")
    }

    /// Parses a URL produced by ``url(scheme:)``. Returns nil for any other URL so the host
    /// can keep handling its own links (profile import and so on).
    public init?(url: URL) {
        guard url.host == Self.host else { return nil }
        let action = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        self.init(rawValue: action.isEmpty ? "home" : action)
    }
}
