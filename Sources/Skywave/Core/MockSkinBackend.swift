import Foundation
import SkywaveShared

/// A backend that simulates a running core with realistic data.
///
/// Used by SwiftUI previews, the demo app, the skin picker thumbnails and tests.
/// It never touches the network.
@MainActor
public final class MockSkinBackend: SkinBackend {
    public enum Scenario: Sendable {
        /// Traffic, connections and logs keep changing every second.
        case live
        /// A fixed, fully populated snapshot. Nothing animates (thumbnails, screenshots).
        case frozen
        /// Service stopped with profiles available.
        case stopped
        /// First launch: no profile yet.
        case empty
    }

    private weak var store: SkinStore?
    private let scenario: Scenario
    private var timer: Timer?
    private var tick = 0
    private var random: SeededRandom

    private var phase: ServicePhase = .running
    private var connectedSince = Date(timeIntervalSinceNow: -6137)
    private var profiles: [SkinProfile] = []
    private var selectedProfile: Int64 = 1
    private var groups: [SkinOutboundGroup] = []
    private var clashMode = "rule"
    private var systemProxy = SkinSystemProxy(available: true, enabled: true)
    private var connections: [SkinConnection] = []
    private var uplinkTotal: Int64 = 327_155_712
    private var downlinkTotal: Int64 = 5_153_960_755
    private var downlink: Double = 19_503_513
    private var uplink: Double = 1_258_291
    private var connectionSeed = 0
    private var logsSubscribed = false

    public init(scenario: Scenario = .live, seed: UInt64 = 7) {
        self.scenario = scenario
        random = SeededRandom(seed: seed)
    }

    // MARK: SkinBackend

    public func attach(to store: SkinStore) {
        self.store = store
        profiles = Self.sampleProfiles
        groups = Self.sampleGroups()
        switch scenario {
        case .empty:
            phase = .unavailable
            profiles = []
        case .stopped:
            phase = .stopped
        case .live, .frozen:
            phase = .running
            connections = (0 ..< 26).map { makeConnection(age: Double($0) * 17, closed: $0 > 19) }
        }
        pushAll()
        store.appendLogs(Self.backlog, reset: true)
        store.apply(defaultLogLevel: .info)
        if scenario == .frozen || scenario == .live {
            // Fill the traffic history so charts have shape from the first frame.
            for index in 0 ..< SkinStore.historyLength {
                let wave = sin(Double(index) / 5) * 0.35 + 0.65
                downlink = 19_503_513 * wave * random.double(in: 0.8 ... 1.1)
                uplink = 1_258_291 * wave * random.double(in: 0.7 ... 1.2)
                store.apply(status: currentStatus())
            }
        }
    }

    public func activate() {
        guard scenario == .live || scenario == .stopped, timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.step()
            }
        }
    }

    public func deactivate() {
        timer?.invalidate()
        timer = nil
    }

    public func startService() async throws {
        guard !profiles.isEmpty else { throw MockError.noProfile }
        try await Task.sleep(for: .milliseconds(700))
        phase = .running
        connectedSince = .now
        uplinkTotal = 0
        downlinkTotal = 0
        connections = []
        pushAll()
        store?.appendLogs([(.info, "sing-box started (0.84s)")])
    }

    public func stopService() async throws {
        try await Task.sleep(for: .milliseconds(450))
        phase = .stopped
        connections = connections.map { var copy = $0; copy.closedAt = copy.closedAt ?? .now; return copy }
        pushAll()
        store?.appendLogs([(.info, "sing-box stopped")])
    }

    public func selectProfile(_ id: Int64) async throws {
        selectedProfile = id
        if phase == .running {
            phase = .reasserting
            pushPhase()
            try await Task.sleep(for: .milliseconds(600))
            phase = .running
        }
        pushAll()
    }

    public func selectOutbound(group: String, outbound: String) async throws {
        try await Task.sleep(for: .milliseconds(120))
        guard let index = groups.firstIndex(where: { $0.tag == group }) else { return }
        groups[index].selected = outbound
        store?.apply(groups: groups)
        store?.appendLogs([(.info, "outbound/selector[\(group)]: selected \(outbound)")])
    }

    public func urlTest(group: String) async throws {
        try await Task.sleep(for: .milliseconds(1400))
        for groupIndex in groups.indices where groups[groupIndex].tag == group || group.isEmpty {
            for itemIndex in groups[groupIndex].items.indices {
                var item = groups[groupIndex].items[itemIndex]
                guard item.delay != UInt16.max, groups.first(where: { $0.tag == item.tag }) == nil else { continue }
                let base = Double(Self.baseDelay[item.tag] ?? 400)
                item.delay = UInt16(max(40, base * random.double(in: 0.85 ... 1.2)))
                item.testedAt = .now
                groups[groupIndex].items[itemIndex] = item
            }
        }
        syncGroupDelays()
        store?.apply(groups: groups)
    }

    public func setGroupExpanded(_ group: String, expanded: Bool) async throws {
        guard let index = groups.firstIndex(where: { $0.tag == group }) else { return }
        groups[index].isExpanded = expanded
    }

    public func setClashMode(_ mode: String) async throws {
        try await Task.sleep(for: .milliseconds(100))
        clashMode = mode
        store?.apply(clashModes: Self.modes, current: mode)
        store?.appendLogs([(.info, "clash-api: switched mode to \(mode)")])
    }

    public func setSystemProxyEnabled(_ enabled: Bool) async throws {
        systemProxy.enabled = enabled
        store?.apply(systemProxy: systemProxy)
    }

    public func closeConnection(id: String) async throws {
        guard let index = connections.firstIndex(where: { $0.id == id }) else { return }
        connections[index].closedAt = .now
        connections[index].uplink = 0
        connections[index].downlink = 0
        store?.apply(connections: connections)
    }

    public func closeAllConnections() async throws {
        connections = connections.map { var copy = $0; copy.closedAt = copy.closedAt ?? .now; copy.uplink = 0; copy.downlink = 0; return copy }
        store?.apply(connections: connections)
    }

    public func clearLogs() async throws {}

    public func performSetup(_ requirement: SkinSetupRequirement) async throws {
        try await Task.sleep(for: .milliseconds(500))
        store?.apply(setupRequirement: nil)
        phase = .stopped
        pushPhase()
    }

    public func disconnectRemote() {
        store?.apply(remoteName: nil)
    }

    public func setConnectionsSubscribed(_ subscribed: Bool) {}

    public func setLogsSubscribed(_ subscribed: Bool) {
        logsSubscribed = subscribed
    }

    // MARK: Simulation

    private func step() {
        tick += 1
        guard phase == .running else { return }
        let target = 14_000_000 + sin(Double(tick) / 6) * 9_000_000
        downlink = max(120_000, downlink * 0.6 + target * 0.4 * random.double(in: 0.75 ... 1.25))
        uplink = max(20_000, downlink * random.double(in: 0.04 ... 0.09))
        downlinkTotal += Int64(downlink)
        uplinkTotal += Int64(uplink)

        let active = connections.indices.filter { connections[$0].isActive }
        let weights = active.map { _ in random.double(in: 0.1 ... 1) }
        let sum = max(weights.reduce(0, +), 0.001)
        for (position, index) in active.enumerated() {
            let share = weights[position] / sum
            let down = Int64(downlink * share)
            let up = Int64(uplink * share)
            connections[index].downlink = down
            connections[index].uplink = up
            connections[index].downlinkTotal += down
            connections[index].uplinkTotal += up
        }
        if tick % 3 == 0 {
            connections.insert(makeConnection(age: 0, closed: false), at: 0)
            if let victim = connections.indices.filter({ connections[$0].isActive }).dropFirst(6).randomElement(using: &random) {
                connections[victim].closedAt = .now
                connections[victim].uplink = 0
                connections[victim].downlink = 0
            }
            if connections.count > 120 {
                connections.removeLast(connections.count - 120)
            }
        }
        store?.apply(status: currentStatus())
        store?.apply(connections: connections)
        if logsSubscribed || tick % 2 == 0 {
            store?.appendLogs(liveLogLines())
        }
        if tick % 20 == 0 {
            for groupIndex in groups.indices {
                for itemIndex in groups[groupIndex].items.indices where groups[groupIndex].items[itemIndex].delay != UInt16.max && groups[groupIndex].items[itemIndex].delay != 0 {
                    let delay = Double(groups[groupIndex].items[itemIndex].delay)
                    groups[groupIndex].items[itemIndex].delay = UInt16(max(40, delay * random.double(in: 0.93 ... 1.07)))
                }
            }
            syncGroupDelays()
            store?.apply(groups: groups)
        }
    }

    private func currentStatus() -> RuntimeStatus {
        let active = connections.filter(\.isActive).count
        return RuntimeStatus(
            memory: 38_000_000 + Int64(tick % 17) * 180_000,
            goroutines: 140 + tick % 11,
            connectionsIn: active,
            connectionsOut: active + active / 3,
            trafficAvailable: true,
            uplink: Int64(uplink),
            downlink: Int64(downlink),
            uplinkTotal: uplinkTotal,
            downlinkTotal: downlinkTotal
        )
    }

    private func pushPhase() {
        store?.apply(phase: phase, connectedSince: phase.isActive ? connectedSince : nil)
    }

    private func pushAll() {
        guard let store else { return }
        pushPhase()
        store.apply(profiles: profiles, selected: profiles.isEmpty ? nil : selectedProfile)
        guard phase.isActive else {
            store.apply(groups: [])
            store.apply(clashModes: [], current: "")
            store.apply(connections: connections)
            store.apply(systemProxy: SkinSystemProxy())
            return
        }
        store.apply(status: currentStatus())
        store.apply(groups: groups)
        store.apply(clashModes: Self.modes, current: clashMode)
        store.apply(connections: connections)
        store.apply(systemProxy: systemProxy)
    }

    /// Keeps `urltest` groups pointing at their fastest member, like the core does.
    private func syncGroupDelays() {
        for index in groups.indices where groups[index].isAutomatic {
            let candidates = groups[index].items.filter { $0.delay > 0 && $0.delay != UInt16.max }
            if let best = candidates.min(by: { $0.delay < $1.delay }) {
                groups[index].selected = best.tag
            }
        }
        // Group entries inside selectors mirror the delay of what they resolved to.
        for index in groups.indices {
            for itemIndex in groups[index].items.indices {
                let tag = groups[index].items[itemIndex].tag
                if let nested = groups.first(where: { $0.tag == tag }), let chosen = nested.items.first(where: { $0.tag == nested.selected }) {
                    groups[index].items[itemIndex].delay = chosen.delay
                }
            }
        }
    }

    // MARK: Sample data

    private enum MockError: LocalizedError {
        case noProfile
        var errorDescription: String? { SkinL("Create or import a profile first.") }
    }

    static let modes = ["rule", "global", "direct"]

    static var sampleProfiles: [SkinProfile] {
        [
            SkinProfile(id: 1, name: SkinL("My Subscription"), isRemote: true, lastUpdated: Date(timeIntervalSinceNow: -7200)),
            SkinProfile(id: 2, name: SkinL("Backup Subscription"), isRemote: true, lastUpdated: Date(timeIntervalSinceNow: -86400 * 3)),
            SkinProfile(id: 3, name: SkinL("Local Config"), isRemote: false),
        ]
    }

    static func node(_ region: String, _ number: Int) -> String {
        let name = Locale.current.localizedString(forRegionCode: region) ?? region
        return "\(flag(region)) \(name) \(String(format: "%02d", number))"
    }

    nonisolated static func flag(_ region: String) -> String {
        region.unicodeScalars.compactMap { UnicodeScalar(127_397 + $0.value) }.map(String.init).joined()
    }

    static let nodeSpecs: [(region: String, number: Int, type: String, delay: UInt16)] = [
        ("HK", 1, "Shadowsocks", 172), ("HK", 2, "Trojan", 186), ("HK", 3, "AnyTLS", 205),
        ("TW", 1, "VLESS", 231), ("SG", 1, "Hysteria2", 248), ("JP", 1, "VMess", 264),
        ("JP", 2, "TUIC", 297), ("KR", 1, "Shadowsocks", 318), ("US", 1, "TUIC", 612),
        ("US", 2, "Hysteria2", 688), ("GB", 1, "Shadowsocks", 905), ("DE", 1, "WireGuard", UInt16.max),
    ]

    static var baseDelay: [String: UInt16] {
        Dictionary(uniqueKeysWithValues: nodeSpecs.map { (node($0.region, $0.number), $0.delay) })
    }

    static func sampleGroups() -> [SkinOutboundGroup] {
        let tested = Date(timeIntervalSinceNow: -240)
        let nodes = nodeSpecs.map { SkinOutbound(tag: node($0.region, $0.number), type: $0.type, delay: $0.delay, testedAt: tested) }
        let proxy = SkinL("Proxy")
        let auto = SkinL("Auto")
        let streaming = SkinL("Streaming")
        let final = SkinL("Final")
        let autoItems = nodes.filter { $0.delay != UInt16.max }
        let autoGroup = SkinOutboundGroup(tag: auto, type: "urltest", displayType: "URLTest", selected: autoItems[0].tag, selectable: false, isExpanded: false, items: autoItems)
        let proxyItems = [SkinOutbound(tag: auto, type: "URLTest", delay: autoItems[0].delay, testedAt: tested)] + nodes
        let proxyGroup = SkinOutboundGroup(tag: proxy, type: "selector", displayType: "Selector", selected: node("HK", 2), selectable: true, isExpanded: true, items: proxyItems)
        let streamingItems = [SkinOutbound(tag: proxy, type: "Selector", delay: 186, testedAt: tested)] + nodes.filter { node in ["SG", "JP", "US", "TW"].contains { node.tag.hasPrefix(flag($0)) } }
        let streamingGroup = SkinOutboundGroup(tag: streaming, type: "selector", displayType: "Selector", selected: node("SG", 1), selectable: true, isExpanded: false, items: streamingItems)
        let finalGroup = SkinOutboundGroup(
            tag: final, type: "selector", displayType: "Selector", selected: proxy, selectable: true, isExpanded: false,
            items: [SkinOutbound(tag: proxy, type: "Selector", delay: 186, testedAt: tested), SkinOutbound(tag: "direct", type: "Direct")]
        )
        return [proxyGroup, autoGroup, streamingGroup, finalGroup]
    }

    private static let destinations: [(host: String, port: Int, network: String, rule: String, direct: Bool, process: String)] = [
        ("github.com", 443, "tcp", "rule_set=geosite-github => route(Proxy)", false, "/Applications/Safari.app"),
        ("api.github.com", 443, "tcp", "rule_set=geosite-github => route(Proxy)", false, "/Applications/Xcode.app"),
        ("en.wikipedia.org", 443, "tcp", "rule_set=geosite-geolocation-!cn => route(Proxy)", false, "/Applications/Safari.app"),
        ("developer.apple.com", 443, "tcp", "domain_suffix=apple.com => route(direct)", true, "/Applications/Safari.app"),
        ("registry.npmjs.org", 443, "tcp", "rule_set=geosite-geolocation-!cn => route(Proxy)", false, "/usr/local/bin/node"),
        ("fonts.gstatic.com", 443, "udp", "rule_set=geosite-google => route(Proxy)", false, "/Applications/Safari.app"),
        ("video.example.com", 443, "udp", "rule_set=geosite-netflix => route(Streaming)", false, "/Applications/TV.app"),
        ("www.bilibili.com", 443, "tcp", "rule_set=geosite-cn => route(direct)", true, "/Applications/Safari.app"),
        ("mail.example.cn", 993, "tcp", "rule_set=geosite-cn => route(direct)", true, "/System/Applications/Mail.app"),
        ("192.168.1.1", 53, "udp", "ip_is_private => route(direct)", true, "/usr/sbin/mDNSResponder"),
        ("time.apple.com", 123, "udp", "domain_suffix=apple.com => route(direct)", true, "/usr/libexec/timed"),
        ("news.ycombinator.com", 443, "tcp", "final => route(Final)", false, "/Applications/Safari.app"),
        ("cdn.jsdelivr.net", 443, "tcp", "rule_set=geosite-geolocation-!cn => route(Proxy)", false, "/Applications/Safari.app"),
    ]

    private func makeConnection(age: TimeInterval, closed: Bool) -> SkinConnection {
        connectionSeed += 1
        let spec = Self.destinations[random.int(below: Self.destinations.count)]
        let proxyNode = resolveLeaf(SkinL("Proxy"))
        let streamingNode = resolveLeaf(SkinL("Streaming"))
        let chain: [String]
        let outbound: String
        let outboundType: String
        if spec.direct || clashMode == "direct" {
            chain = ["direct"]
            outbound = "direct"
            outboundType = "direct"
        } else if spec.rule.contains("Streaming"), let streamingNode {
            chain = [streamingNode, SkinL("Streaming")]
            outbound = streamingNode
            outboundType = "hysteria2"
        } else {
            let leaf = proxyNode ?? Self.node("HK", 2)
            chain = spec.rule.contains("Final") ? [leaf, SkinL("Proxy"), SkinL("Final")] : [leaf, SkinL("Proxy")]
            outbound = leaf
            outboundType = "trojan"
        }
        let created = Date(timeIntervalSinceNow: -age - random.double(in: 0 ... 30))
        let total = Int64(random.double(in: 4_000 ... 40_000_000))
        let rule = spec.rule
            .replacingOccurrences(of: "route(Proxy)", with: "route(\(SkinL("Proxy")))")
            .replacingOccurrences(of: "route(Streaming)", with: "route(\(SkinL("Streaming")))")
            .replacingOccurrences(of: "route(Final)", with: "route(\(SkinL("Final")))")
        let isIP = spec.host.first?.isNumber == true
        return SkinConnection(
            id: "mock-\(connectionSeed)",
            inbound: "tun-in",
            inboundType: "tun",
            ipVersion: 4,
            network: spec.network,
            source: "172.19.0.1:\(49152 + random.int(below: 16000))",
            destination: isIP ? "\(spec.host):\(spec.port)" : "203.0.113.\(10 + random.int(below: 200)):\(spec.port)",
            domain: isIP ? "" : spec.host,
            displayDestination: "\(spec.host):\(spec.port)",
            protocolName: spec.port == 443 ? (spec.network == "udp" ? "quic" : "tls") : (spec.port == 53 ? "dns" : ""),
            createdAt: created,
            closedAt: closed ? created.addingTimeInterval(random.double(in: 2 ... 60)) : nil,
            uplinkTotal: total / Int64(random.int(below: 20) + 8),
            downlinkTotal: total,
            rule: rule,
            outbound: outbound,
            outboundType: outboundType,
            chain: chain,
            processPath: spec.process
        )
    }

    /// Walks nested selections (`Proxy` → `Auto` → node) down to the leaf outbound.
    private func resolveLeaf(_ tag: String) -> String? {
        var current = tag
        var seen: Set<String> = []
        while let group = groups.first(where: { $0.tag == current }), !seen.contains(current) {
            seen.insert(current)
            current = group.selected
        }
        return current == tag ? nil : current
    }

    private func liveLogLines() -> [(level: SkinLogLevel, message: String)] {
        guard let connection = connections.first(where: \.isActive) else { return [] }
        let id = 1000 + tick
        var lines: [(SkinLogLevel, String)] = [
            (.info, "[\(id) 0ms] inbound/tun[tun-in]: inbound connection from \(connection.source)"),
            (.info, "[\(id) 1ms] router: match[\(tick % 9)] \(connection.rule)"),
            (.info, "[\(id) \(20 + tick % 40)ms] outbound/\(connection.outboundType)[\(connection.outbound)]: outbound connection to \(connection.displayDestination)"),
        ]
        if tick % 13 == 0 {
            lines.append((.warn, "[\(id) 5002ms] outbound/wireguard[\(Self.node("DE", 1))]: dial timeout"))
        }
        if tick % 29 == 0 {
            lines.append((.error, "[\(id) 88ms] connection: reset by peer: push.example.com:5223"))
        }
        if tick % 7 == 0 {
            lines.append((.debug, "dns: exchanged \(connection.hostName) A 1 answers"))
        }
        return lines
    }

    private static var backlog: [(level: SkinLogLevel, message: String)] {
        [
            (.info, "sing-box started (0.84s)"),
            (.info, "inbound/tun[tun-in]: started at utun4"),
            (.info, "outbound/urltest[\(SkinL("Auto"))]: selected \(node("HK", 1))"),
            (.warn, "outbound/wireguard[\(node("DE", 1))]: health check failed: i/o timeout"),
            (.info, "[1000 0ms] inbound/tun[tun-in]: inbound connection from 172.19.0.1:52114"),
            (.info, "[1000 1ms] router: match[2] rule_set=geosite-github => route(\(SkinL("Proxy")))"),
            (.info, "[1000 42ms] outbound/trojan[\(node("HK", 2))]: outbound connection to github.com:443"),
            (.debug, "dns: exchanged github.com A 1 answers"),
        ]
    }
}

/// Deterministic generator so previews and thumbnails always look the same.
struct SeededRandom: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed &* 0x9E37_79B9_7F4A_7C15 | 1
    }

    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }

    mutating func double(in range: ClosedRange<Double>) -> Double {
        Double.random(in: range, using: &self)
    }

    mutating func int(below upperBound: Int) -> Int {
        Int.random(in: 0 ..< max(upperBound, 1), using: &self)
    }
}
