import SBSkinShared
import SwiftUI

/// A live, non-interactive miniature of a skin's phone home screen, rendered from frozen
/// sample data. Used by the skin picker and onboarding so users see the real thing.
struct SkinThumbnail: View {
    let skin: SkinID
    /// Design size of the miniature (an iPhone portrait screen).
    var canvas = CGSize(width: 390, height: 844)

    var body: some View {
        let context = SkinThumbnailContext.shared
        GeometryReader { proxy in
            let scale = proxy.size.width / canvas.width
            SkinCanvas(skin: skin)
                .environment(context.store)
                .environment(context.preferences(for: skin))
                .environment(context.router)
                .environment(\.horizontalSizeClass, .compact)
                .environment(\.skinThumbnailMode, true)
                .frame(width: canvas.width, height: canvas.height)
                .scaleEffect(scale, anchor: .topLeading)
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
                .clipped()
        }
        .aspectRatio(canvas.width / canvas.height, contentMode: .fit)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

@MainActor
final class SkinThumbnailContext {
    static let shared = SkinThumbnailContext()

    let store = SkinStore(backend: MockSkinBackend(scenario: .frozen))
    let router = SkinRouter()
    private var preferencesBySkin: [SkinID: SkinPreferences] = [:]

    func preferences(for skin: SkinID) -> SkinPreferences {
        if let existing = preferencesBySkin[skin] { return existing }
        let defaults = UserDefaults(suiteName: "sbskin.thumbnail.\(skin.rawValue)") ?? .standard
        let preferences = SkinPreferences(defaults: defaults)
        preferences.skin = skin
        preferences.hasChosenSkin = true
        preferences.vocabularyOverride = nil
        preferencesBySkin[skin] = preferences
        return preferences
    }
}

struct SkinThumbnailModeKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// True inside a thumbnail: skins skip sheets, timers and heavy effects.
    var skinThumbnailMode: Bool {
        get { self[SkinThumbnailModeKey.self] }
        set { self[SkinThumbnailModeKey.self] = newValue }
    }
}
