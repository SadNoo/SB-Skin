import Foundation
import SkywaveShared

/// Lifecycle of the proxy service as the skins see it.
public enum ServicePhase: Sendable, Equatable {
    /// No profile yet, or the VPN configuration is not installed.
    case unavailable
    case stopped
    case starting
    case running
    case reasserting
    case stopping

    public var isActive: Bool {
        switch self {
        case .running, .reasserting, .starting: true
        default: false
        }
    }

    public var isTransitioning: Bool {
        switch self {
        case .starting, .stopping, .reasserting: true
        default: false
        }
    }
}

/// Mirrors `LibboxStatusMessage`.
public struct RuntimeStatus: Sendable, Equatable {
    public var memory: Int64
    public var goroutines: Int
    public var connectionsIn: Int
    public var connectionsOut: Int
    public var trafficAvailable: Bool
    public var uplink: Int64
    public var downlink: Int64
    public var uplinkTotal: Int64
    public var downlinkTotal: Int64

    public init(
        memory: Int64 = 0,
        goroutines: Int = 0,
        connectionsIn: Int = 0,
        connectionsOut: Int = 0,
        trafficAvailable: Bool = false,
        uplink: Int64 = 0,
        downlink: Int64 = 0,
        uplinkTotal: Int64 = 0,
        downlinkTotal: Int64 = 0
    ) {
        self.memory = memory
        self.goroutines = goroutines
        self.connectionsIn = connectionsIn
        self.connectionsOut = connectionsOut
        self.trafficAvailable = trafficAvailable
        self.uplink = uplink
        self.downlink = downlink
        self.uplinkTotal = uplinkTotal
        self.downlinkTotal = downlinkTotal
    }

    public var totalConnections: Int { connectionsIn + connectionsOut }
    public var totalTraffic: Int64 { uplinkTotal + downlinkTotal }
}

/// Mirrors upstream `OutboundGroupItem`.
public struct SkinOutbound: Sendable, Equatable, Identifiable, Hashable {
    public var tag: String
    /// Display type such as `Shadowsocks`, already humanized by the core.
    public var type: String
    /// 0 means not tested yet.
    public var delay: UInt16
    public var testedAt: Date?

    public var id: String { tag }

    public init(tag: String, type: String, delay: UInt16 = 0, testedAt: Date? = nil) {
        self.tag = tag
        self.type = type
        self.delay = delay
        self.testedAt = testedAt
    }

    public var grade: LatencyGrade { LatencyGrade(delay: delay) }
}

/// Mirrors upstream `OutboundGroup`.
public struct SkinOutboundGroup: Sendable, Equatable, Identifiable, Hashable {
    public var tag: String
    /// Raw type such as `selector` or `urltest`.
    public var type: String
    /// Display type such as `Selector` or `URLTest`.
    public var displayType: String
    public var selected: String
    public var selectable: Bool
    public var isExpanded: Bool
    public var items: [SkinOutbound]

    public var id: String { tag }

    public init(tag: String, type: String, displayType: String? = nil, selected: String, selectable: Bool, isExpanded: Bool = true, items: [SkinOutbound]) {
        self.tag = tag
        self.type = type
        self.displayType = displayType ?? type
        self.selected = selected
        self.selectable = selectable
        self.isExpanded = isExpanded
        self.items = items
    }

    public var selectedItem: SkinOutbound? {
        items.first { $0.tag == selected }
    }

    /// `urltest` groups pick their member automatically.
    public var isAutomatic: Bool {
        type.lowercased() == "urltest"
    }
}

/// Mirrors upstream `Connection` (built from `LibboxConnection`).
public struct SkinConnection: Sendable, Equatable, Identifiable, Hashable {
    public var id: String
    public var inbound: String
    public var inboundType: String
    public var ipVersion: Int
    public var network: String
    public var source: String
    public var destination: String
    public var domain: String
    public var displayDestination: String
    public var protocolName: String
    public var user: String
    public var fromOutbound: String
    public var createdAt: Date
    public var closedAt: Date?
    public var uplink: Int64
    public var downlink: Int64
    public var uplinkTotal: Int64
    public var downlinkTotal: Int64
    public var rule: String
    public var outbound: String
    public var outboundType: String
    public var chain: [String]
    /// Only some platforms report the owning process.
    public var processPath: String?

    public init(
        id: String,
        inbound: String = "",
        inboundType: String = "",
        ipVersion: Int = 4,
        network: String = "tcp",
        source: String = "",
        destination: String,
        domain: String = "",
        displayDestination: String? = nil,
        protocolName: String = "",
        user: String = "",
        fromOutbound: String = "",
        createdAt: Date,
        closedAt: Date? = nil,
        uplink: Int64 = 0,
        downlink: Int64 = 0,
        uplinkTotal: Int64 = 0,
        downlinkTotal: Int64 = 0,
        rule: String = "",
        outbound: String = "",
        outboundType: String = "",
        chain: [String] = [],
        processPath: String? = nil
    ) {
        self.id = id
        self.inbound = inbound
        self.inboundType = inboundType
        self.ipVersion = ipVersion
        self.network = network
        self.source = source
        self.destination = destination
        self.domain = domain
        self.displayDestination = displayDestination ?? (domain.isEmpty ? destination : domain)
        self.protocolName = protocolName
        self.user = user
        self.fromOutbound = fromOutbound
        self.createdAt = createdAt
        self.closedAt = closedAt
        self.uplink = uplink
        self.downlink = downlink
        self.uplinkTotal = uplinkTotal
        self.downlinkTotal = downlinkTotal
        self.rule = rule
        self.outbound = outbound
        self.outboundType = outboundType
        self.chain = chain
        self.processPath = processPath
    }

    public var isActive: Bool { closedAt == nil }

    /// Direct and blocked connections bypass the proxy.
    public var isDirect: Bool {
        let type = outboundType.lowercased()
        return type == "direct" || type == "block" || type == "reject"
    }

    public var totalBytes: Int64 { uplinkTotal + downlinkTotal }

    /// Host part of the destination for display (`github.com` from `github.com:443`).
    public var hostName: String {
        if !domain.isEmpty { return domain }
        return Self.stripPort(destination)
    }

    public var processName: String? {
        guard let processPath, !processPath.isEmpty else { return nil }
        let last = (processPath as NSString).lastPathComponent
        return last.hasSuffix(".app") ? String(last.dropLast(4)) : last
    }

    /// Chain from the outermost group to the final outbound, e.g. `["Proxy", "Hong Kong 02"]`.
    public var route: [String] {
        chain.isEmpty ? [outbound] : chain.reversed()
    }

    /// Short form of the matched rule: `rule_set=geosite-github => route(Proxy)` → `geosite-github`.
    public var ruleSummary: String {
        let condition = rule.components(separatedBy: "=>").first?.trimmingCharacters(in: .whitespaces) ?? ""
        guard !condition.isEmpty else { return "" }
        let value = condition.split(separator: "=", maxSplits: 1).last.map(String.init) ?? condition
        return value.trimmingCharacters(in: CharacterSet(charactersIn: "[] "))
    }

    static func stripPort(_ address: String) -> String {
        if address.hasPrefix("["), let end = address.firstIndex(of: "]") {
            return String(address[address.index(after: address.startIndex) ..< end])
        }
        if address.filter({ $0 == ":" }).count == 1, let colon = address.lastIndex(of: ":") {
            return String(address[..<colon])
        }
        return address
    }
}

public enum SkinLogLevel: Int, Sendable, CaseIterable, Comparable, Identifiable {
    case panic = 0
    case fatal = 1
    case error = 2
    case warn = 3
    case info = 4
    case debug = 5
    case trace = 6

    public var id: Int { rawValue }

    public static func < (lhs: SkinLogLevel, rhs: SkinLogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var name: String {
        switch self {
        case .panic: "PANIC"
        case .fatal: "FATAL"
        case .error: "ERROR"
        case .warn: "WARN"
        case .info: "INFO"
        case .debug: "DEBUG"
        case .trace: "TRACE"
        }
    }

    /// Levels a user can filter by, matching upstream.
    public static let filterable: [SkinLogLevel] = [.error, .warn, .info, .debug, .trace]
}

public struct SkinLogEntry: Sendable, Equatable, Identifiable {
    public var id: Int
    public var level: SkinLogLevel
    /// Raw message; may contain ANSI escapes from the core.
    public var message: String

    public init(id: Int, level: SkinLogLevel, message: String) {
        self.id = id
        self.level = level
        self.message = message
    }

    /// Message with ANSI color escapes removed.
    public var plainMessage: String {
        message.replacingOccurrences(of: "\u{1B}\\[[0-9;]*m", with: "", options: .regularExpression)
    }
}

public struct SkinProfile: Sendable, Equatable, Identifiable, Hashable {
    public var id: Int64
    public var name: String
    public var isRemote: Bool
    public var lastUpdated: Date?

    public init(id: Int64, name: String, isRemote: Bool, lastUpdated: Date? = nil) {
        self.id = id
        self.name = name
        self.isRemote = isRemote
        self.lastUpdated = lastUpdated
    }
}

public struct SkinSystemProxy: Sendable, Equatable {
    public var available: Bool
    public var enabled: Bool

    public init(available: Bool = false, enabled: Bool = false) {
        self.available = available
        self.enabled = enabled
    }
}

/// An error surfaced to the user.
public struct SkinAlert: Identifiable, Sendable, Equatable {
    public let id = UUID()
    public var title: String
    public var message: String

    public init(title: String, message: String) {
        self.title = title
        self.message = message
    }
}

/// Something the system needs before the service can run. Mirrors the install buttons the
/// upstream dashboard shows.
public enum SkinSetupRequirement: Sendable, Equatable {
    /// iOS / macOS App Store build: the VPN configuration is not installed yet.
    case installNetworkExtension
    /// macOS standalone build: the system extension is not installed yet.
    case installSystemExtension

    var title: String {
        switch self {
        case .installNetworkExtension: SkinL("Install Network Extension")
        case .installSystemExtension: SkinL("Install System Extension")
        }
    }

    var message: String {
        switch self {
        case .installNetworkExtension: SkinL("The system will ask you to allow adding a VPN configuration.")
        case .installSystemExtension: SkinL("The system will ask you to allow the extension in System Settings.")
        }
    }
}
