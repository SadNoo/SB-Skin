#if os(iOS)
    import ActivityKit
    import Foundation

    /// Live Activity shown on the Lock Screen and in the Dynamic Island while the service runs.
    ///
    /// The app starts it when the service starts and ends it when the service stops.
    /// The elapsed time renders with a system timer, so it keeps counting even while the
    /// app is suspended; speeds refresh whenever the app is able to push an update.
    public struct SkinActivityAttributes: ActivityAttributes {
        public struct ContentState: Codable, Hashable, Sendable {
            public var isRunning: Bool
            public var connectedSince: Date?
            public var groupTag: String
            public var nodeTag: String
            public var nodeDelay: UInt16
            public var mode: String
            public var uplink: Int64
            public var downlink: Int64
            public var downlinkHistory: [Double]

            public init(
                isRunning: Bool,
                connectedSince: Date?,
                groupTag: String,
                nodeTag: String,
                nodeDelay: UInt16,
                mode: String,
                uplink: Int64,
                downlink: Int64,
                downlinkHistory: [Double]
            ) {
                self.isRunning = isRunning
                self.connectedSince = connectedSince
                self.groupTag = groupTag
                self.nodeTag = nodeTag
                self.nodeDelay = nodeDelay
                self.mode = mode
                self.uplink = uplink
                self.downlink = downlink
                self.downlinkHistory = downlinkHistory
            }

            public init(snapshot: SkinWidgetSnapshot) {
                self.init(
                    isRunning: snapshot.isRunning,
                    connectedSince: snapshot.connectedSince,
                    groupTag: snapshot.groupTag,
                    nodeTag: snapshot.nodeTag,
                    nodeDelay: snapshot.nodeDelay,
                    mode: snapshot.mode,
                    uplink: snapshot.uplink,
                    downlink: snapshot.downlink,
                    downlinkHistory: Array(snapshot.downlinkHistory.suffix(20))
                )
            }
        }

        public var profileName: String
        public var skin: SkinID
        public var vocabulary: SkinVocabulary
        public var deepLinkScheme: String?

        public init(profileName: String, skin: SkinID, vocabulary: SkinVocabulary, deepLinkScheme: String?) {
            self.profileName = profileName
            self.skin = skin
            self.vocabulary = vocabulary
            self.deepLinkScheme = deepLinkScheme
        }
    }
#endif
