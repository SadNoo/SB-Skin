import Observation
import SBSkinShared
import SwiftUI

/// Cross-skin navigation requests: deep links, the command palette and shared sheets.
/// Each skin decides how to present them (a tab, a sheet, a side panel…).
@MainActor
@Observable
public final class SkinRouter {
    public enum Sheet: String, Identifiable {
        case nodes
        case profiles
        case appearance
        case connections
        case logs
        case more

        public var id: String { rawValue }
    }

    /// A sheet the current skin should show.
    public var sheet: Sheet?
    /// Group to focus when the node picker opens; `nil` means the primary group.
    public var focusedGroup: String?
    public var showsCommandPalette = false
    /// Incremented when a deep link asks for the “home” surface, so skins can pop to root.
    public private(set) var homeRequests = 0

    public init() {}

    public func showNodes(group: String? = nil) {
        focusedGroup = group
        sheet = .nodes
    }

    func goHome() {
        sheet = nil
        homeRequests += 1
    }

    /// Handles a widget / Live Activity link. Returns false for URLs that are not ours.
    @discardableResult
    public func handle(_ url: URL, store: SkinStore) -> Bool {
        guard let link = SkinDeepLink(url: url) else { return false }
        switch link {
        case .home: goHome()
        case .nodes: showNodes()
        case .activity: sheet = .connections
        case .start: store.startService()
        case .stop: store.stopService()
        case .toggle: store.toggleService()
        }
        return true
    }
}
