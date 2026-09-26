import Foundation
import Observation
import SBSkinShared
import SwiftUI

/// Single source of truth every skin renders from.
///
/// Backends push state in through the `apply…` methods; skins call the action methods, which
/// update optimistically where upstream does, forward to the backend and turn failures into
/// ``alert``.
@MainActor
@Observable
public final class SkinStore {
    public static let historyLength = 60
    public static let maxLogEntries = 3000

    // MARK: Service

    public private(set) var phase: ServicePhase = .unavailable
    public private(set) var connectedSince: Date?

    // MARK: Runtime status

    public private(set) var status = RuntimeStatus()
    public private(set) var uplinkHistory = Array(repeating: 0.0, count: SkinStore.historyLength)
    public private(set) var downlinkHistory = Array(repeating: 0.0, count: SkinStore.historyLength)

    // MARK: Outbounds

    public private(set) var groups: [SkinOutboundGroup] = []
    public private(set) var groupsLoaded = false
    public private(set) var testingGroups: Set<String> = []

    // MARK: Clash mode

    public private(set) var clashModes: [String] = []
    public private(set) var clashMode = ""

    // MARK: Connections

    public private(set) var connections: [SkinConnection] = []
    public private(set) var connectionsLoaded = false

    // MARK: Logs

    public private(set) var logs: [SkinLogEntry] = []
    public private(set) var logsLoaded = false
    public private(set) var defaultLogLevel: SkinLogLevel = .info
    private var nextLogID = 0

    // MARK: Profiles

    public private(set) var profiles: [SkinProfile] = []
    public private(set) var selectedProfileID: Int64?
    public private(set) var isSwitchingProfile = false

    // MARK: System proxy (macOS)

    public private(set) var systemProxy = SkinSystemProxy()

    // MARK: Setup & remote

    public private(set) var setupRequirement: SkinSetupRequirement?
    public private(set) var isPerformingSetup = false
    /// Name of the remote device being controlled, if any.
    public private(set) var remoteName: String?

    // MARK: Misc

    public var alert: SkinAlert?

    @ObservationIgnored public let backend: SkinBackend
    @ObservationIgnored private var pendingSelections: [String: String] = [:]
    @ObservationIgnored private var connectionSubscribers = 0
    @ObservationIgnored private var logSubscribers = 0

    public init(backend: SkinBackend) {
        self.backend = backend
        backend.attach(to: self)
    }

    // MARK: - Derived

    public var isRunning: Bool { phase == .running || phase == .reasserting }

    public var activeProfile: SkinProfile? {
        profiles.first { $0.id == selectedProfileID }
    }

    /// The group most people mean by “the node”: the first manual selector, else the first group.
    public var primaryGroup: SkinOutboundGroup? {
        groups.first { $0.selectable && !$0.isAutomatic } ?? groups.first
    }

    public func group(_ tag: String) -> SkinOutboundGroup? {
        groups.first { $0.tag == tag }
    }

    /// Follows nested groups: a selector that picked an `urltest` group resolves to the node that
    /// group chose. Returns the leaf outbound and the chain of group tags walked through.
    public func resolvedNode(in group: SkinOutboundGroup) -> (node: SkinOutbound?, via: [String]) {
        var via: [String] = []
        var current = group
        var seen: Set<String> = [group.tag]
        while let item = current.selectedItem, let nested = self.group(item.tag), !seen.contains(nested.tag) {
            via.append(nested.tag)
            seen.insert(nested.tag)
            current = nested
        }
        return (current.selectedItem, via)
    }

    public var currentNode: SkinOutbound? {
        guard let primaryGroup else { return nil }
        return resolvedNode(in: primaryGroup).node
    }

    public var activeConnections: [SkinConnection] {
        connections.filter(\.isActive)
    }

    /// Bytes carried by tracked connections that went through a proxy vs. directly.
    public var routeSplit: (proxied: Int64, direct: Int64) {
        var proxied: Int64 = 0
        var direct: Int64 = 0
        for connection in connections {
            if connection.isDirect {
                direct += connection.totalBytes
            } else {
                proxied += connection.totalBytes
            }
        }
        return (proxied, direct)
    }

    public var hasProfiles: Bool { !profiles.isEmpty || remoteName != nil }

    /// True when a skin should show the shared setup / first-profile card instead of controls.
    public var needsGate: Bool { !hasProfiles || setupRequirement != nil }

    // MARK: - Actions

    public func toggleService() {
        if phase.isActive {
            stopService()
        } else {
            startService()
        }
    }

    public func startService() {
        if setupRequirement != nil {
            performSetup()
            return
        }
        guard phase == .stopped else { return }
        phase = .starting
        run(SkinL("Start service")) { try await $0.startService() } onFailure: { store in
            store.phase = .stopped
        }
    }

    public func stopService() {
        if remoteName != nil {
            disconnectRemote()
            return
        }
        guard phase.isActive else { return }
        phase = .stopping
        run(SkinL("Stop service")) { try await $0.stopService() }
    }

    public func selectProfile(_ id: Int64) {
        guard id != selectedProfileID else { return }
        let previous = selectedProfileID
        selectedProfileID = id
        isSwitchingProfile = true
        run(SkinL("Switch profile")) { try await $0.selectProfile(id) } onFailure: { store in
            store.selectedProfileID = previous
        } always: { store in
            store.isSwitchingProfile = false
        }
    }

    public func select(_ outbound: String, in groupTag: String) {
        guard let index = groups.firstIndex(where: { $0.tag == groupTag }), groups[index].selectable else { return }
        groups[index].selected = outbound
        pendingSelections[groupTag] = outbound
        run(SkinL("Select outbound")) { try await $0.selectOutbound(group: groupTag, outbound: outbound) } onFailure: { store in
            store.pendingSelections.removeValue(forKey: groupTag)
        }
    }

    public func urlTest(_ groupTag: String) {
        guard !testingGroups.contains(groupTag) else { return }
        testingGroups.insert(groupTag)
        run(SkinL("Run URL test")) { try await $0.urlTest(group: groupTag) } always: { store in
            store.testingGroups.remove(groupTag)
        }
    }

    public func urlTestAll() {
        for group in groups {
            urlTest(group.tag)
        }
    }

    public var isTestingAny: Bool { !testingGroups.isEmpty }

    public func setExpanded(_ groupTag: String, _ expanded: Bool) {
        guard let index = groups.firstIndex(where: { $0.tag == groupTag }) else { return }
        groups[index].isExpanded = expanded
        run(SkinL("Update group")) { try await $0.setGroupExpanded(groupTag, expanded: expanded) }
    }

    public func setClashMode(_ mode: String) {
        guard mode != clashMode else { return }
        let previous = clashMode
        clashMode = mode
        run(SkinL("Change mode")) { try await $0.setClashMode(mode) } onFailure: { store in
            store.clashMode = previous
        }
    }

    public func setSystemProxy(_ enabled: Bool) {
        let previous = systemProxy.enabled
        systemProxy.enabled = enabled
        run(SkinL("Update system proxy")) { try await $0.setSystemProxyEnabled(enabled) } onFailure: { store in
            store.systemProxy.enabled = previous
        }
    }

    public func close(_ connection: SkinConnection) {
        run(SkinL("Close connection")) { try await $0.closeConnection(id: connection.id) }
    }

    public func closeAllConnections() {
        run(SkinL("Close all connections")) { try await $0.closeAllConnections() }
    }

    public func clearLogs() {
        logs.removeAll()
        run(SkinL("Clear logs")) { try await $0.clearLogs() }
    }

    public func performSetup() {
        guard let requirement = setupRequirement, !isPerformingSetup else { return }
        isPerformingSetup = true
        run(requirement.title) { try await $0.performSetup(requirement) } always: { store in
            store.isPerformingSetup = false
        }
    }

    public func disconnectRemote() {
        backend.disconnectRemote()
    }

    // MARK: Subscriptions

    public func retainConnections() {
        connectionSubscribers += 1
        if connectionSubscribers == 1 {
            backend.setConnectionsSubscribed(true)
        }
    }

    public func releaseConnections() {
        connectionSubscribers = max(connectionSubscribers - 1, 0)
        if connectionSubscribers == 0 {
            backend.setConnectionsSubscribed(false)
        }
    }

    public func retainLogs() {
        logSubscribers += 1
        if logSubscribers == 1 {
            backend.setLogsSubscribed(true)
        }
    }

    public func releaseLogs() {
        logSubscribers = max(logSubscribers - 1, 0)
        if logSubscribers == 0 {
            backend.setLogsSubscribed(false)
        }
    }

    // MARK: - Backend push API

    public func apply(phase: ServicePhase, connectedSince: Date?) {
        if self.phase != phase {
            self.phase = phase
        }
        if self.connectedSince != connectedSince {
            self.connectedSince = connectedSince
        }
        if !phase.isActive, status != RuntimeStatus() {
            status = RuntimeStatus()
            uplinkHistory = Array(repeating: 0, count: Self.historyLength)
            downlinkHistory = Array(repeating: 0, count: Self.historyLength)
        }
    }

    public func apply(status newStatus: RuntimeStatus) {
        status = newStatus
        guard newStatus.trafficAvailable else { return }
        uplinkHistory.removeFirst()
        uplinkHistory.append(Double(newStatus.uplink))
        downlinkHistory.removeFirst()
        downlinkHistory.append(Double(newStatus.downlink))
    }

    public func apply(groups newGroups: [SkinOutboundGroup]) {
        var merged = newGroups
        for index in merged.indices {
            let tag = merged[index].tag
            if let pending = pendingSelections[tag] {
                if merged[index].selected == pending {
                    pendingSelections.removeValue(forKey: tag)
                } else {
                    merged[index].selected = pending
                }
            }
        }
        if merged != groups {
            groups = merged
        }
        groupsLoaded = true
    }

    public func apply(clashModes modes: [String], current: String) {
        if clashModes != modes { clashModes = modes }
        if clashMode != current { clashMode = current }
    }

    public func apply(connections newConnections: [SkinConnection]) {
        connections = newConnections
        connectionsLoaded = true
    }

    public func apply(defaultLogLevel level: SkinLogLevel) {
        defaultLogLevel = level
    }

    /// Appends raw log lines. Pass `reset` when the backend delivers a fresh backlog.
    public func appendLogs(_ entries: [(level: SkinLogLevel, message: String)], reset: Bool = false) {
        if reset {
            logs.removeAll(keepingCapacity: true)
        }
        var batch: [SkinLogEntry] = []
        batch.reserveCapacity(entries.count)
        for entry in entries {
            batch.append(SkinLogEntry(id: nextLogID, level: entry.level, message: entry.message))
            nextLogID += 1
        }
        logs.append(contentsOf: batch)
        if logs.count > Self.maxLogEntries {
            logs.removeFirst(logs.count - Self.maxLogEntries)
        }
        logsLoaded = true
    }

    public func apply(profiles newProfiles: [SkinProfile], selected: Int64?) {
        if profiles != newProfiles { profiles = newProfiles }
        if !isSwitchingProfile, selectedProfileID != selected { selectedProfileID = selected }
    }

    public func apply(setupRequirement requirement: SkinSetupRequirement?) {
        if setupRequirement != requirement { setupRequirement = requirement }
    }

    public func apply(remoteName name: String?) {
        if remoteName != name { remoteName = name }
    }

    public func apply(systemProxy newValue: SkinSystemProxy) {
        if systemProxy != newValue { systemProxy = newValue }
    }

    public func report(_ error: Error, action: String) {
        alert = SkinAlert(title: action, message: error.localizedDescription)
    }

    // MARK: - Helpers

    private func run(
        _ action: String,
        _ body: @escaping @MainActor (SkinBackend) async throws -> Void,
        onFailure: (@MainActor (SkinStore) -> Void)? = nil,
        always: (@MainActor (SkinStore) -> Void)? = nil
    ) {
        let backend = backend
        Task { @MainActor [weak self] in
            do {
                try await body(backend)
            } catch {
                guard let self else { return }
                onFailure?(self)
                self.report(error, action: action)
            }
            if let self {
                always?(self)
            }
        }
    }
}
