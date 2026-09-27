// Skywave ⇄ sing-box Apple client bridge.
//
// Compile this file into the SFI (iOS) and SFM (macOS) app targets of
// https://github.com/SagerNet/sing-box (clients/apple). It only uses APIs the upstream
// client already uses for its own dashboard, so every skin keeps exactly the upstream
// feature set. See INTEGRATION.md.
//
// SPDX-License-Identifier: GPL-3.0-or-later

import ApplicationLibrary
import Combine
import Foundation
import Libbox
import Library
import NetworkExtension
import Skywave

@MainActor
public final class UpstreamSkinBackend: SkinBackend {
    private let environments: ExtensionEnvironments
    private weak var store: SkinStore?

    private var cancellables = Set<AnyCancellable>()
    private var clientCancellables = Set<AnyCancellable>()
    private var profileCancellables = Set<AnyCancellable>()
    private let connectionClient = CommandClient([.connections])
    private var connectionsSubscribed = false
    private var loggedTotal = 0
    private var startRequested = false
    private var active = false
    #if os(macOS)
        private var systemExtensionInstalled = true
    #endif

    public init(environments: ExtensionEnvironments) {
        self.environments = environments
    }

    // MARK: - SkinBackend

    public func attach(to store: SkinStore) {
        self.store = store

        environments.$commandClient
            .sink { [weak self] client in self?.bind(client: client) }
            .store(in: &cancellables)
        environments.$extensionProfile
            .sink { [weak self] profile in self?.bind(profile: profile) }
            .store(in: &cancellables)
        environments.$extensionProfileLoading
            .combineLatest(environments.$emptyProfiles)
            .sink { [weak self] _, _ in self?.pushPhase() }
            .store(in: &cancellables)
        environments.$remoteServer
            .sink { [weak self] server in
                self?.store?.apply(remoteName: server?.displayName)
                self?.pushPhase()
            }
            .store(in: &cancellables)
        environments.profileUpdate
            .merge(with: environments.selectedProfileUpdate)
            .sink { [weak self] _ in Task { await self?.reloadProfiles() } }
            .store(in: &cancellables)

        // Connections come from their own subscription, like upstream's connection list.
        connectionClient.$connections
            .compactMap { $0 }
            .sink { [weak self] connections in
                self?.store?.apply(connections: connections.compactMap(Self.convert))
            }
            .store(in: &cancellables)
        connectionClient.$connectionStateFilter
            .sink { [weak self] filter in
                // Skins filter active/closed themselves; always receive everything.
                guard let self, filter != .all else { return }
                connectionClient.connectionStateFilter = .all
                connectionClient.filterConnectionsNow()
            }
            .store(in: &cancellables)

        Task {
            await reloadProfiles()
            #if os(macOS)
                await checkSystemExtension()
            #endif
        }
    }

    public func activate() {
        active = true
        environments.postReload()
        environments.connect()
        Task {
            await reloadProfiles()
            await reloadSystemProxy()
            #if os(macOS)
                await checkSystemExtension()
            #endif
        }
        if connectionsSubscribed {
            connectionClient.connect()
        }
    }

    public func deactivate() {
        active = false
        connectionClient.disconnect()
    }

    public func startService() async throws {
        guard let profile = environments.extensionProfile else { return }
        startRequested = true
        do {
            try await profile.start()
        } catch {
            startRequested = false
            throw error
        }
    }

    public func stopService() async throws {
        if environments.remoteServer != nil {
            environments.exitRemoteControl()
            return
        }
        try await environments.extensionProfile?.stop()
    }

    public func selectProfile(_ id: Int64) async throws {
        await SharedPreferences.selectedProfileID.set(id)
        environments.selectedProfileUpdate.send()
        if let profile = environments.extensionProfile, profile.status.isConnected {
            try await profile.reloadService()
        }
        await reloadProfiles()
    }

    public func selectOutbound(group: String, outbound: String) async throws {
        try await Self.command { try $0.selectOutbound(group, outboundTag: outbound) }
    }

    public func urlTest(group: String) async throws {
        try await Self.command { try $0.urlTest(group) }
    }

    public func setGroupExpanded(_ group: String, expanded: Bool) async throws {
        try await Self.command { try $0.setGroupExpand(group, isExpand: expanded) }
    }

    public func setClashMode(_ mode: String) async throws {
        try await Self.command { try $0.setClashMode(mode) }
    }

    /// Same behavior as upstream's `OverviewViewModel.setSystemProxyEnabled`.
    public func setSystemProxyEnabled(_ enabled: Bool) async throws {
        await SharedPreferences.systemProxyEnabled.set(enabled)
        if enabled {
            try await Task.detached {
                try LibboxNewStandaloneCommandClient()!.setSystemProxyEnabled(true)
            }.value
        } else {
            try await environments.extensionProfile?.restart()
        }
        await reloadSystemProxy()
    }

    public func closeConnection(id: String) async throws {
        try await Self.command { try $0.closeConnection(id) }
    }

    public func closeAllConnections() async throws {
        try await Self.command { try $0.closeConnections() }
    }

    public func clearLogs() async throws {
        environments.commandClient.clearLogs()
        loggedTotal = 0
        try await Self.command { try $0.clearLogs() }
    }

    public func performSetup(_ requirement: SkinSetupRequirement) async throws {
        switch requirement {
        case .installNetworkExtension:
            try await ExtensionProfile.install()
            await environments.reload()
        case .installSystemExtension:
            #if os(macOS)
                _ = try await SystemExtension.install()
                await SharedPreferences.rootHelperPromptPending.set(true)
                NotificationCenter.default.post(name: .systemExtensionInstalled, object: nil)
                await checkSystemExtension()
                await environments.reload()
            #endif
        }
        pushPhase()
    }

    public func disconnectRemote() {
        environments.exitRemoteControl()
    }

    public func setConnectionsSubscribed(_ subscribed: Bool) {
        connectionsSubscribed = subscribed
        if subscribed, active {
            connectionClient.connect()
        } else if !subscribed {
            connectionClient.disconnect()
        }
    }

    public func setLogsSubscribed(_ subscribed: Bool) {
        // Logs arrive through the shared command client that upstream keeps connected
        // while the service runs; nothing extra to open here.
        if subscribed {
            environments.connect()
        }
    }

    // MARK: - Bindings

    private func bind(client: CommandClient) {
        clientCancellables.removeAll()
        loggedTotal = 0

        client.statusPublisher
            .compactMap { $0 }
            .sink { [weak self] message in
                self?.store?.apply(status: RuntimeStatus(
                    memory: message.memory,
                    goroutines: Int(message.goroutines),
                    connectionsIn: Int(message.connectionsIn),
                    connectionsOut: Int(message.connectionsOut),
                    trafficAvailable: message.trafficAvailable,
                    uplink: message.uplink,
                    downlink: message.downlink,
                    uplinkTotal: message.uplinkTotal,
                    downlinkTotal: message.downlinkTotal
                ))
            }
            .store(in: &clientCancellables)

        client.$groups
            .compactMap { $0 }
            .sink { [weak self] groups in
                self?.store?.apply(groups: groups.map(Self.convert))
            }
            .store(in: &clientCancellables)

        client.$clashModeList
            .combineLatest(client.$clashMode)
            .sink { [weak self] modes, current in
                self?.store?.apply(clashModes: modes, current: current)
            }
            .store(in: &clientCancellables)

        client.$logBuffer
            .sink { [weak self] buffer in self?.push(logs: buffer) }
            .store(in: &clientCancellables)

        client.$defaultLogLevel
            .sink { [weak self] level in
                self?.store?.apply(defaultLogLevel: SkinLogLevel(rawValue: level) ?? .info)
            }
            .store(in: &clientCancellables)

        client.$isConnected
            .sink { [weak self] _ in self?.pushPhase() }
            .store(in: &clientCancellables)
    }

    private func bind(profile: ExtensionProfile?) {
        profileCancellables.removeAll()
        guard let profile else {
            pushPhase()
            return
        }
        profile.$status
            .combineLatest(profile.$connectedDate)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status, _ in
                guard let self else { return }
                pushPhase()
                if status.isConnectedStrict {
                    startRequested = false
                    environments.connect()
                    Task { await self.reloadSystemProxy() }
                    if connectionsSubscribed, active {
                        connectionClient.connect()
                    }
                } else if status == .disconnected, startRequested {
                    // Same check upstream's start button does after a failed start.
                    startRequested = false
                    Task { @MainActor in
                        if let alert = await profile.checkLastDisconnectError() {
                            self.store?.alert = SkinAlert(title: alert.title, message: alert.message)
                        }
                    }
                }
            }
            .store(in: &profileCancellables)
    }

    private func pushPhase() {
        guard let store else { return }
        if environments.remoteServer != nil {
            let client = environments.commandClient
            if client.isConnected, client.startedAt == nil {
                client.loadStartedAt()
            }
            store.apply(phase: client.isConnected ? .running : .starting, connectedSince: client.startedAt)
            store.apply(setupRequirement: nil)
            return
        }
        #if os(macOS)
            if Variant.useSystemExtension, !systemExtensionInstalled {
                store.apply(phase: .unavailable, connectedSince: nil)
                store.apply(setupRequirement: .installSystemExtension)
                return
            }
        #endif
        if environments.extensionProfileLoading {
            store.apply(phase: .unavailable, connectedSince: nil)
            store.apply(setupRequirement: nil)
            return
        }
        guard let profile = environments.extensionProfile else {
            store.apply(phase: .unavailable, connectedSince: nil)
            store.apply(setupRequirement: .installNetworkExtension)
            return
        }
        store.apply(setupRequirement: nil)
        let phase: ServicePhase = switch profile.status {
        case .connected: .running
        case .connecting: .starting
        case .reasserting: .reasserting
        case .disconnecting: .stopping
        case .disconnected: .stopped
        default: .unavailable
        }
        store.apply(phase: phase, connectedSince: profile.status.isConnectedStrict ? profile.connectedDate : nil)
    }

    private func push(logs buffer: LogBuffer) {
        guard let store else { return }
        let total = buffer.totalCount
        if total < loggedTotal || loggedTotal == 0 {
            // Fresh backlog (connect, clear, or reconnect).
            store.appendLogs(buffer.entries.map(Self.convert), reset: true)
        } else if total > loggedTotal {
            let newCount = min(total - loggedTotal, buffer.entries.count)
            store.appendLogs(buffer.entries.suffix(newCount).map(Self.convert))
        }
        loggedTotal = total
    }

    private func reloadProfiles() async {
        guard let profiles = try? await ProfileManager.list() else { return }
        let selected = await SharedPreferences.selectedProfileID.get()
        let converted = profiles.map { profile in
            SkinProfile(id: profile.mustID, name: profile.name, isRemote: profile.type == .remote, lastUpdated: profile.lastUpdated)
        }
        let selectedID = converted.contains(where: { $0.id == selected }) ? selected : converted.first?.id
        store?.apply(profiles: converted, selected: selectedID)
        pushPhase()
    }

    private func reloadSystemProxy() async {
        let status = try? await Task.detached {
            try LibboxNewStandaloneCommandClient()!.getSystemProxyStatus()
        }.value
        store?.apply(systemProxy: SkinSystemProxy(available: status?.available ?? false, enabled: status?.enabled ?? false))
    }

    #if os(macOS)
        private func checkSystemExtension() async {
            guard Variant.useSystemExtension else { return }
            systemExtensionInstalled = await SystemExtension.isInstalled()
            pushPhase()
        }
    #endif

    // MARK: - Conversion

    /// Runs a command-client call off the main thread, like upstream's view models do.
    private nonisolated static func command(_ body: @escaping @Sendable (LibboxCommandClient) throws -> Void) async throws {
        try await Task.detached {
            try body(CommandTarget.standaloneClient())
        }.value
    }

    private static func convert(_ group: OutboundGroup) -> SkinOutboundGroup {
        SkinOutboundGroup(
            tag: group.tag,
            type: group.type,
            displayType: group.displayType,
            selected: group.selected,
            selectable: group.selectable,
            isExpanded: group.isExpand,
            items: group.items.map { item in
                SkinOutbound(tag: item.tag, type: item.displayType, delay: item.urlTestDelay, testedAt: item.urlTestDelay > 0 ? item.urlTestTime : nil)
            }
        )
    }

    private static func convert(_ entry: LogEntry) -> (level: SkinLogLevel, message: String) {
        (SkinLogLevel(rawValue: entry.level) ?? .info, entry.message)
    }

    /// Mirrors upstream `ConnectionDataModel.convertConnections` (DNS connections are hidden).
    private static func convert(_ connection: LibboxConnection) -> SkinConnection? {
        guard connection.outboundType != "dns" else { return nil }
        return SkinConnection(
            id: connection.id_,
            inbound: connection.inbound,
            inboundType: connection.inboundType,
            ipVersion: Int(connection.ipVersion),
            network: connection.network,
            source: connection.source,
            destination: connection.destination,
            domain: connection.domain,
            displayDestination: connection.displayDestination(),
            protocolName: connection.protocol,
            user: connection.user,
            fromOutbound: connection.fromOutbound,
            createdAt: Date(timeIntervalSince1970: Double(connection.createdAt) / 1000),
            closedAt: connection.closedAt > 0 ? Date(timeIntervalSince1970: Double(connection.closedAt) / 1000) : nil,
            uplink: connection.uplink,
            downlink: connection.downlink,
            uplinkTotal: connection.uplinkTotal,
            downlinkTotal: connection.downlinkTotal,
            rule: connection.rule,
            outbound: connection.outbound,
            outboundType: connection.outboundType,
            chain: connection.chain()?.toArray() ?? []
        )
    }
}
