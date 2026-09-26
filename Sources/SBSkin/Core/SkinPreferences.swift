import Foundation
import Observation
import SBSkinShared
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
/// upstream database), optionally mirrored to iCloud so iPhone, iPad and Mac can match.
@MainActor
@Observable
public final class SkinPreferences {
    private enum Key {
        static let skin = "sbskin.skin"
        static let hasChosenSkin = "sbskin.hasChosenSkin"
        static let vocabulary = "sbskin.vocabulary"
        static let appearance = "sbskin.appearance"
        static let iconFollowsSkin = "sbskin.iconFollowsSkin"
        static let syncAcrossDevices = "sbskin.syncAcrossDevices"
        static let bentoModules = "sbskin.bento.modules"
        static let logLevel = "sbskin.logLevel"
        static let radioBand = "sbskin.radio.band"
    }

    public var skin: SkinID {
        didSet { save(skin.rawValue, Key.skin, synced: true) }
    }

    /// False until the user finishes (or skips) the first-launch skin picker.
    public var hasChosenSkin: Bool {
        didSet { defaults.set(hasChosenSkin, forKey: Key.hasChosenSkin) }
    }

    /// `nil` follows the skin's own default.
    public var vocabularyOverride: SkinVocabulary? {
        didSet { save(vocabularyOverride?.rawValue, Key.vocabulary, synced: true) }
    }

    public var appearance: SkinAppearance {
        didSet { save(appearance.rawValue, Key.appearance, synced: true) }
    }

    public var iconFollowsSkin: Bool {
        didSet { defaults.set(iconFollowsSkin, forKey: Key.iconFollowsSkin) }
    }

    public var syncAcrossDevices: Bool {
        didSet { defaults.set(syncAcrossDevices, forKey: Key.syncAcrossDevices) }
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
    @ObservationIgnored private var cloudObserver: NSObjectProtocol?

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        skin = defaults.string(forKey: Key.skin).flatMap(SkinID.init(rawValue:)) ?? .default
        hasChosenSkin = defaults.bool(forKey: Key.hasChosenSkin)
        vocabularyOverride = defaults.string(forKey: Key.vocabulary).flatMap(SkinVocabulary.init(rawValue:))
        appearance = defaults.string(forKey: Key.appearance).flatMap(SkinAppearance.init(rawValue:)) ?? .system
        iconFollowsSkin = defaults.object(forKey: Key.iconFollowsSkin) as? Bool ?? true
        syncAcrossDevices = defaults.bool(forKey: Key.syncAcrossDevices)
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

    // MARK: iCloud

    /// Starts mirroring skin, vocabulary and appearance through iCloud key-value storage.
    public func enableCloudSync() {
        guard cloudObserver == nil else { return }
        let store = NSUbiquitousKeyValueStore.default
        store.synchronize()
        pullFromCloud()
        cloudObserver = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.pullFromCloud()
            }
        }
    }

    private func pullFromCloud() {
        guard syncAcrossDevices else { return }
        let store = NSUbiquitousKeyValueStore.default
        if let value = store.string(forKey: Key.skin).flatMap(SkinID.init(rawValue:)), value != skin {
            skin = value
        }
        if let value = store.string(forKey: Key.appearance).flatMap(SkinAppearance.init(rawValue:)), value != appearance {
            appearance = value
        }
        let vocabulary = store.string(forKey: Key.vocabulary).flatMap(SkinVocabulary.init(rawValue:))
        if vocabulary != vocabularyOverride {
            vocabularyOverride = vocabulary
        }
    }

    private func save(_ value: String?, _ key: String, synced: Bool) {
        defaults.set(value, forKey: key)
        guard synced, syncAcrossDevices, cloudObserver != nil else { return }
        NSUbiquitousKeyValueStore.default.set(value, forKey: key)
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
