// Signature stubs of the gomobile-generated Libbox framework, as seen from Swift.
// Only declarations used by Integration/Apple. No behavior.

import Foundation

public protocol LibboxStringIteratorProtocol: AnyObject {
    func hasNext() -> Bool
    func next() -> String
}

open class LibboxStatusMessage: NSObject {
    open var memory: Int64 = 0
    open var goroutines: Int32 = 0
    open var connectionsIn: Int32 = 0
    open var connectionsOut: Int32 = 0
    open var trafficAvailable = false
    open var uplink: Int64 = 0
    open var downlink: Int64 = 0
    open var uplinkTotal: Int64 = 0
    open var downlinkTotal: Int64 = 0
}

open class LibboxConnection: NSObject {
    open var id_: String = ""
    open var inbound: String = ""
    open var inboundType: String = ""
    open var ipVersion: Int32 = 4
    open var network: String = ""
    open var source: String = ""
    open var destination: String = ""
    open var domain: String = ""
    open var `protocol`: String = ""
    open var user: String = ""
    open var fromOutbound: String = ""
    open var createdAt: Int64 = 0
    open var closedAt: Int64 = 0
    open var uplink: Int64 = 0
    open var downlink: Int64 = 0
    open var uplinkTotal: Int64 = 0
    open var downlinkTotal: Int64 = 0
    open var rule: String = ""
    open var outbound: String = ""
    open var outboundType: String = ""
    open func displayDestination() -> String { "" }
    open func chain() -> (any LibboxStringIteratorProtocol)? { nil }
}

open class LibboxSystemProxyStatus: NSObject {
    open var available = false
    open var enabled = false
}

open class LibboxCommandClient: NSObject {
    open func selectOutbound(_ groupTag: String?, outboundTag: String?) throws {}
    open func urlTest(_ groupTag: String?) throws {}
    open func setGroupExpand(_ groupTag: String?, isExpand: Bool) throws {}
    open func setClashMode(_ mode: String?) throws {}
    open func closeConnection(_ connId: String?) throws {}
    open func closeConnections() throws {}
    open func clearLogs() throws {}
    open func getSystemProxyStatus() throws -> LibboxSystemProxyStatus { LibboxSystemProxyStatus() }
    open func setSystemProxyEnabled(_ isEnabled: Bool) throws {}
}

public func LibboxNewStandaloneCommandClient() -> LibboxCommandClient? { LibboxCommandClient() }
