// Signature stubs of the upstream `Library` framework (clients/apple/Library).
// Only declarations used by Integration/Apple. No behavior.

import Combine
import Foundation
import Libbox
import NetworkExtension
import SwiftUI

public extension LibboxStringIteratorProtocol {
    func toArray() -> [String] { [] }
}

// MARK: CommandClient.swift

public struct LogEntry: Identifiable {
    public let id = UUID()
    public let level: Int
    public let message: String
}

public struct LogBuffer {
    public var entries: [LogEntry] = []
    public var droppedCount: Int = 0
    public var totalCount: Int { droppedCount + entries.count }
}

public enum ConnectionStateFilter: Int, CaseIterable, Identifiable {
    public var id: Self { self }
    case all
    case active
    case closed
}

public class CommandClient: ObservableObject {
    public enum ConnectionType {
        case status, groups, log, clashMode, connections, outbounds
    }

    @Published public var isConnected = false
    @Published public private(set) var startedAt: Date?
    @Published public var groups: [OutboundGroup]?
    @Published public var logBuffer = LogBuffer()
    @Published public var defaultLogLevel = 0
    @Published public var clashModeList: [String] = []
    @Published public var clashMode = ""
    @Published public var connectionStateFilter = ConnectionStateFilter.active
    @Published public var connections: [LibboxConnection]?

    public var statusPublisher: AnyPublisher<LibboxStatusMessage?, Never> {
        Just(nil).eraseToAnyPublisher()
    }

    public init(_ connectionTypes: [ConnectionType], logMaxLines: Int = 3000, localOnly: Bool = false) {}
    public func connect() {}
    public func disconnect() {}
    public func loadStartedAt() {}
    public func clearLogs() {}
    public func filterConnectionsNow() {}
}

// MARK: OutboundGroup.swift

public struct OutboundGroup: Codable, Hashable {
    public let tag: String
    public let type: String
    public let displayType: String
    public var selected: String
    public let selectable: Bool
    public var isExpand: Bool
    public var items: [OutboundGroupItem]
}

public struct OutboundGroupItem: Codable, Hashable {
    public let tag: String
    public let type: String
    public let displayType: String
    public let urlTestTime: Date
    public let urlTestDelay: UInt16
}

// MARK: ExtensionProfile.swift / NEVPNStatus+isConnected.swift

public class ExtensionProfile: ObservableObject {
    @Published public var status: NEVPNStatus = .invalid
    @Published public var connectedDate: Date?
    public func start() async throws {}
    public func stop() async throws {}
    public func reloadService() async throws {}
    public func restart() async throws {}
    public static func install() async throws {}
}

public extension NEVPNStatus {
    var isConnected: Bool { false }
    var isConnectedStrict: Bool { false }
}

// MARK: ExtensionEnvironments.swift

public struct AlertState: Identifiable {
    public let id = UUID()
    public var title: String
    public var message: String
}

public extension View {
    func alert(_ binding: Binding<AlertState?>) -> some View { self }
}

public struct ImportRemoteProfileRequest: Hashable, Identifiable {
    public var id: String { url }
    public let name: String
    public let url: String
}

public class RemoteServer {
    public var displayName: String { "" }
}

@MainActor
public class ExtensionEnvironments: ObservableObject {
    @Published public var commandClient = CommandClient([.log, .status, .groups, .clashMode])
    @Published public var extensionProfileLoading = true
    @Published public var extensionProfile: ExtensionProfile?
    @Published public var emptyProfiles = false
    @Published public var pendingImportRemoteProfile: ImportRemoteProfileRequest?
    @Published public var remoteServer: RemoteServer?
    public var toolsBadgeCount: Int { 0 }
    public let profileUpdate = ObjectWillChangePublisher()
    public let selectedProfileUpdate = ObjectWillChangePublisher()

    public init() {}
    public func postReload() {}
    public func reload() async {}
    public func connect() {}
    public func exitRemoteControl() {}
}

// MARK: Database

public enum ProfileType: Int {
    case local = 0, icloud, remote
}

public class Profile {
    public var mustID: Int64 { 0 }
    public var name = ""
    public var type = ProfileType.local
    public var lastUpdated: Date?
}

public enum ProfileManager {
    public nonisolated static func list() async throws -> [Profile] { [] }
}

public enum SharedPreferences {
    public class Preference<T: Codable> {
        init(_ name: String, defaultValue: T) {}
        public nonisolated func get() async -> T { fatalError() }
        public nonisolated func set(_ newValue: T?) async {}
    }

    public static let selectedProfileID = Preference<Int64>("selected_profile_id", defaultValue: -1)
    public static let systemProxyEnabled = Preference<Bool>("system_proxy_enabled", defaultValue: true)
    #if os(macOS)
        public static let rootHelperPromptPending = Preference<Bool>("root_helper_prompt_pending", defaultValue: false)
    #endif
}

// MARK: Network

public enum CommandTarget {
    public static func standaloneClient() throws -> LibboxCommandClient { LibboxCommandClient() }
}

public enum Variant {
    #if os(macOS)
        public static var useSystemExtension = false
    #else
        public static let useSystemExtension = false
    #endif
}

#if os(macOS)
    import SystemExtensions

    public extension Notification.Name {
        static let systemExtensionInstalled = Notification.Name("systemExtensionInstalled")
    }

    public class SystemExtension: NSObject {
        public static func isInstalled() async -> Bool { true }
        public nonisolated static func install(forceUpdate: Bool = false, inBackground: Bool = false) async throws -> OSSystemExtensionRequest.Result? { nil }
    }
#endif
