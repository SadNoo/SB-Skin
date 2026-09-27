import Foundation
import Observation
import SkywaveShared
import SwiftUI

public enum SkinAppearance: String, CaseIterable, Codable, Sendable, Identifiable {
    case system
    case light
    case dark

    public var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    var displayName: String {
        switch self {
        case .system: SkinL("Automatic")
        case .light: SkinL("Light")
        case .dark: SkinL("Dark")
        }
    }
}

/// User choices that belong to the skin layer. Stored in the app's own defaults (not the
/// upstream database) and never synced: each device keeps its own choice, so devices on
/// different Skywave versions (with different skin sets) never fight over it.
@MainActor
@Observable
public final class SkinPreferences {
    private enum Key {
        static let skin = "skywave.skin"
        static let hasChosenSkin = "skywave.hasChosenSkin"
        static let vocabulary = "skywave.vocabulary"
        static let appearance = "skywave.appearance"
        static let iconFollowsSkin = "skywave.iconFollowsSkin"
        static let bentoModules = "skywave.bento.modules"
        static let logLevel = "skywave.logLevel"
        static let radioBand = "skywave.radio.band"
    }

    public var skin: SkinID {
        didSet { defaults.set(skin.rawValue, forKey: Key.skin) }
    }

    /// False until the user finishes (or skips) the first-launch skin picker.
    public var hasChosenSkin: Bool {
        didSet { defaults.set(hasChosenSkin, forKey: Key.hasChosenSkin) }
    }

    /// `nil` follows the skin's own default.
    public var vocabularyOverride: SkinVocabulary? {
        didSet { defaults.set(vocabularyOverride?.rawValue, forKey: Key.vocabulary) }
    }

    public var appearance: SkinAppearance {
        didSet { defaults.set(appearance.rawValue, forKey: Key.appearance) }
    }

    public var iconFollowsSkin: Bool {
        didSet { defaults.set(iconFollowsSkin, forKey: Key.iconFollowsSkin) }
    }

    /// Order of modules on the Bento home. Unknown ids are ignored when loading.
    public var bentoModules: [String] {
        didSet { defaults.set(bentoModules, forKey: Key.bentoModules) }
    }

    public var logLevel: SkinLogLevel {
        didSet { defaults.set(logLevel.rawValue, forKey: Key.logLevel) }
    }

    /// Group the Radio skin is tuned to.
    public var radioBand: String? {
        didSet { defaults.set(radioBand, forKey: Key.radioBand) }
    }

    @ObservationIgnored private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        skin = defaults.string(forKey: Key.skin).flatMap(SkinID.init(rawValue:)) ?? .default
        hasChosenSkin = defaults.bool(forKey: Key.hasChosenSkin)
        vocabularyOverride = defaults.string(forKey: Key.vocabulary).flatMap(SkinVocabulary.init(rawValue:))
        appearance = defaults.string(forKey: Key.appearance).flatMap(SkinAppearance.init(rawValue:)) ?? .system
        iconFollowsSkin = defaults.object(forKey: Key.iconFollowsSkin) as? Bool ?? true
        bentoModules = defaults.stringArray(forKey: Key.bentoModules) ?? BentoModuleID.defaultOrder.map(\.rawValue)
        logLevel = SkinLogLevel(rawValue: defaults.integer(forKey: Key.logLevel)) ?? .info
        if defaults.object(forKey: Key.logLevel) == nil {
            logLevel = .info
        }
        radioBand = defaults.string(forKey: Key.radioBand)
    }

    /// Vocabulary actually in use for the current skin.
    public var vocabulary: SkinVocabulary {
        vocabularyOverride ?? skin.defaultVocabulary
    }
}

extension SkinID {
    /// Plain words suit the consumer-style skins; numbers suit the data-heavy ones.
    var defaultVocabulary: SkinVocabulary {
        switch self {
        case .focus, .places, .sentence: .everyday
        case .native, .instrument, .lens, .radio, .bento: .technical
        }
    }
}
