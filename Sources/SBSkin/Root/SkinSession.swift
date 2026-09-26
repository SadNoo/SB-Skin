import Observation
import SBSkinShared
import SwiftUI

/// Everything the skin layer needs, created once by the host.
///
/// ```swift
/// @State private var session = SkinSession(backend: UpstreamSkinBackend(environments: environments),
///                                          configuration: configuration)
/// var body: some View { SkinRootView(session: session) }
/// ```
@MainActor
@Observable
public final class SkinSession {
    public let store: SkinStore
    public let preferences: SkinPreferences
    public let router: SkinRouter
    public var configuration: SkinConfiguration

    public init(backend: SkinBackend, configuration: SkinConfiguration = SkinConfiguration(), preferences: SkinPreferences? = nil) {
        store = SkinStore(backend: backend)
        let preferences = preferences ?? SkinPreferences()
        self.preferences = preferences
        router = SkinRouter()
        self.configuration = configuration
        if configuration.syncWithICloud {
            preferences.enableCloudSync()
        }
    }

    /// Forward URLs the host receives. Returns true when the URL was a skin deep link.
    @discardableResult
    public func handle(_ url: URL) -> Bool {
        router.handle(url, store: store)
    }

    /// Session backed by sample data; for previews and the demo app.
    public static func preview(_ scenario: MockSkinBackend.Scenario = .live, skin: SkinID? = nil) -> SkinSession {
        let defaults = UserDefaults(suiteName: "sbskin.preview") ?? .standard
        let preferences = SkinPreferences(defaults: defaults)
        if let skin {
            preferences.skin = skin
            preferences.hasChosenSkin = true
        }
        return SkinSession(backend: MockSkinBackend(scenario: scenario), preferences: preferences)
    }
}
