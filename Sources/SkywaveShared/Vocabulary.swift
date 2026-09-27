import SwiftUI

/// How the UI talks about the network: plain words or engineering terms.
/// Every skin honors this setting; a skin only picks the default.
public enum SkinVocabulary: String, CaseIterable, Codable, Sendable, Identifiable {
    /// “Very fast”, “Smart routing”.
    case everyday
    /// “52 ms”, “Rule”.
    case technical

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .everyday: SharedL("Everyday words")
        case .technical: SharedL("Technical terms")
        }
    }
}

/// Buckets a URL-test delay the same way the upstream client colors it
/// (< 800 ms good, < 1500 ms medium, otherwise bad), with one extra
/// “excellent” tier below 300 ms for the everyday vocabulary.
public enum LatencyGrade: Int, Sendable, Comparable {
    case untested
    case unreachable
    case poor
    case fair
    case good
    case excellent

    public init(delay: UInt16) {
        switch delay {
        case 0: self = .untested
        case UInt16.max: self = .unreachable
        case ..<300: self = .excellent
        case ..<800: self = .good
        case ..<1500: self = .fair
        default: self = .poor
        }
    }

    public static func < (lhs: LatencyGrade, rhs: LatencyGrade) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// 0…3 signal bars.
    public var bars: Int {
        switch self {
        case .excellent: 3
        case .good: 2
        case .fair, .poor: 1
        case .unreachable, .untested: 0
        }
    }

    public var word: String {
        switch self {
        case .excellent: SharedL("Very fast")
        case .good: SharedL("Good")
        case .fair: SharedL("Fair")
        case .poor: SharedL("Slow")
        case .unreachable: SharedL("Unreachable")
        case .untested: SharedL("Not tested")
        }
    }

    /// Semantic tint. Light and dark variants follow the upstream palette.
    public var color: Color {
        switch self {
        case .excellent, .good: SkinPalette.good
        case .fair: SkinPalette.medium
        case .poor, .unreachable: SkinPalette.bad
        case .untested: .secondary
        }
    }
}

public extension SkinVocabulary {
    /// `52 ms` or `Very fast`.
    func latency(_ delay: UInt16) -> String {
        let grade = LatencyGrade(delay: delay)
        switch self {
        case .everyday:
            return grade.word
        case .technical:
            switch grade {
            case .untested: return "—"
            case .unreachable: return SharedL("Timeout")
            default: return "\(delay) ms"
            }
        }
    }

    /// Display name for a Clash mode reported by the core. Unknown custom modes pass through.
    func mode(_ raw: String) -> String {
        switch (raw.lowercased(), self) {
        case ("rule", .everyday): SharedL("Smart routing")
        case ("rule", .technical): SharedL("Rule")
        case ("global", .everyday): SharedL("Everything via proxy")
        case ("global", .technical): SharedL("Global")
        case ("direct", .everyday): SharedL("No proxy")
        case ("direct", .technical): SharedL("Direct")
        default: raw
        }
    }

    /// Short mode label for segmented controls.
    func modeShort(_ raw: String) -> String {
        switch (raw.lowercased(), self) {
        case ("rule", .everyday): SharedL("Smart")
        case ("global", .everyday): SharedL("All")
        case ("direct", .everyday): SharedL("Off")
        default: mode(raw)
        }
    }
}

/// Semantic colors shared by skins and widgets.
public enum SkinPalette {
    public static let good = Color(light: Color(red: 0.14, green: 0.54, blue: 0.24), dark: Color(red: 0.49, green: 0.80, blue: 0.56))
    public static let medium = Color(light: Color(red: 0.66, green: 0.37, blue: 0.0), dark: Color(red: 0.93, green: 0.68, blue: 0.33))
    public static let bad = Color(light: Color(red: 0.76, green: 0.17, blue: 0.14), dark: Color(red: 1.0, green: 0.48, blue: 0.43))
    public static let upload = Color(light: Color(red: 0.79, green: 0.20, blue: 0.0), dark: Color(red: 1.0, green: 0.62, blue: 0.35))
    public static let download = Color(light: Color(red: 0.04, green: 0.38, blue: 0.84), dark: Color(red: 0.39, green: 0.71, blue: 1.0))
}

public extension Color {
    /// A color that resolves differently in light and dark appearance.
    init(light: Color, dark: Color) {
        #if os(macOS)
            self.init(nsColor: NSColor(name: nil) { appearance in
                appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? NSColor(dark) : NSColor(light)
            })
        #else
            self.init(uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
            })
        #endif
    }

    /// `Color(hex: 0x1C1C1E)`
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}
