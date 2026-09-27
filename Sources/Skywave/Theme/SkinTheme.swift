import SkywaveShared
import SwiftUI

/// Design tokens of one skin. Shared pages (nodes, connections, logs, settings) read these so
/// that they blend into whichever skin is active.
public struct SkinTheme: Sendable {
    public var id: SkinID
    public var background: Color
    public var surface: Color
    public var elevatedSurface: Color
    public var text: Color
    public var secondaryText: Color
    public var separator: Color
    public var accent: Color
    public var onAccent: Color
    public var upload: Color
    public var download: Color
    public var cornerRadius: CGFloat
    public var textDesign: Font.Design
    public var numberDesign: Font.Design
    /// `nil` follows the user's appearance setting.
    public var forcedColorScheme: ColorScheme?
    /// Use Liquid Glass for floating chrome.
    public var usesGlass: Bool

    func font(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .system(style, design: textDesign, weight: weight)
    }

    func number(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: numberDesign).monospacedDigit()
    }
}

extension SkinTheme {
    static func of(_ id: SkinID) -> SkinTheme {
        switch id {
        case .native: .native
        case .instrument: .instrument
        case .focus: .focus
        case .places: .places
        case .lens: .lens
        case .sentence: .sentence
        case .radio: .radio
        case .bento: .bento
        }
    }

    static let native = SkinTheme(
        id: .native,
        background: Color(light: Color(hex: 0xF2F2F7), dark: .black),
        surface: Color(light: .white, dark: Color(hex: 0x1C1C1E)),
        elevatedSurface: Color(light: Color(hex: 0xF2F2F7), dark: Color(hex: 0x2C2C2E)),
        text: .primary,
        secondaryText: .secondary,
        separator: Color(light: Color(hex: 0xE5E5EA), dark: Color(hex: 0x38383A)),
        accent: Color(light: Color(hex: 0x0A60D6), dark: Color(hex: 0x0A84FF)),
        onAccent: .white,
        upload: SkinPalette.upload,
        download: SkinPalette.download,
        cornerRadius: 26,
        textDesign: .default,
        numberDesign: .default,
        forcedColorScheme: nil,
        usesGlass: true
    )

    static let instrument = SkinTheme(
        id: .instrument,
        background: Color(hex: 0x0A0C0F),
        surface: Color(hex: 0x13171C),
        elevatedSurface: Color(hex: 0x1B2027),
        text: Color(hex: 0xE8ECF1),
        secondaryText: Color(hex: 0x8B95A1),
        separator: Color.white.opacity(0.07),
        accent: Color(hex: 0x4CC9F0),
        onAccent: Color(hex: 0x06222C),
        upload: Color(hex: 0xF7B538),
        download: Color(hex: 0x4CC9F0),
        cornerRadius: 16,
        textDesign: .default,
        numberDesign: .monospaced,
        forcedColorScheme: .dark,
        usesGlass: true
    )

    static let focus = SkinTheme(
        id: .focus,
        background: Color(light: Color(hex: 0xE9EEE8), dark: Color(hex: 0x0F1512)),
        surface: Color(light: Color.white.opacity(0.72), dark: Color(hex: 0x18211C)),
        elevatedSurface: Color(light: .white, dark: Color(hex: 0x1F2A24)),
        text: Color(light: Color(hex: 0x1B2620), dark: Color(hex: 0xE4ECE6)),
        secondaryText: Color(light: Color(hex: 0x56645C), dark: Color(hex: 0x93A29A)),
        separator: Color(light: Color(hex: 0x1B2620, opacity: 0.1), dark: Color.white.opacity(0.08)),
        accent: Color(light: Color(hex: 0x2D6A4F), dark: Color(hex: 0x52B788)),
        onAccent: Color(light: .white, dark: Color(hex: 0x0B2117)),
        upload: Color(light: Color(hex: 0x9A4500), dark: Color(hex: 0xF4A259)),
        download: Color(light: Color(hex: 0x2D6A4F), dark: Color(hex: 0x74C69D)),
        cornerRadius: 24,
        textDesign: .rounded,
        numberDesign: .rounded,
        forcedColorScheme: nil,
        usesGlass: true
    )

    static let places = SkinTheme(
        id: .places,
        background: Color(light: Color(hex: 0xDFE7EE), dark: Color(hex: 0x0E1822)),
        surface: Color(light: Color.white, dark: Color(hex: 0x17232F)),
        elevatedSurface: Color(light: Color(hex: 0xF5F7F9), dark: Color(hex: 0x1F2D3A)),
        text: Color(light: Color(hex: 0x17212B), dark: Color(hex: 0xE6EDF3)),
        secondaryText: Color(light: Color(hex: 0x5D6B78), dark: Color(hex: 0x93A3B3)),
        separator: Color(light: Color(hex: 0xEDF0F3), dark: Color.white.opacity(0.07)),
        accent: Color(light: Color(hex: 0xC4461C), dark: Color(hex: 0xFF7A4D)),
        onAccent: .white,
        upload: Color(light: Color(hex: 0xA24A00), dark: Color(hex: 0xFFB47A)),
        download: Color(light: Color(hex: 0x17212B), dark: Color(hex: 0xE6EDF3)),
        cornerRadius: 22,
        textDesign: .rounded,
        numberDesign: .rounded,
        forcedColorScheme: nil,
        usesGlass: true
    )

    static let lens = SkinTheme(
        id: .lens,
        background: Color(light: Color(hex: 0xF4F4F7), dark: Color(hex: 0x0C0C10)),
        surface: Color(light: .white, dark: Color(hex: 0x17171D)),
        elevatedSurface: Color(light: Color(hex: 0xF7F7FA), dark: Color(hex: 0x202028)),
        text: Color(light: Color(hex: 0x15151A), dark: Color(hex: 0xECECF1)),
        secondaryText: Color(light: Color(hex: 0x62626D), dark: Color(hex: 0x9A9AA6)),
        separator: Color(light: Color(hex: 0xEFEFF3), dark: Color.white.opacity(0.07)),
        accent: Color(light: Color(hex: 0x4338CA), dark: Color(hex: 0x8B85FF)),
        onAccent: .white,
        upload: Color(light: Color(hex: 0x4338CA), dark: Color(hex: 0x8B85FF)),
        download: Color(light: Color(hex: 0x4338CA), dark: Color(hex: 0x8B85FF)),
        cornerRadius: 24,
        textDesign: .default,
        numberDesign: .default,
        forcedColorScheme: nil,
        usesGlass: true
    )

    static let sentence = SkinTheme(
        id: .sentence,
        background: Color(light: Color(hex: 0xF3EEE5), dark: Color(hex: 0x171512)),
        surface: Color(light: Color(hex: 0xF8F4EC), dark: Color(hex: 0x201D19)),
        elevatedSurface: Color(light: Color(hex: 0xFBF8F2), dark: Color(hex: 0x2A2621)),
        text: Color(light: Color(hex: 0x1F1C17), dark: Color(hex: 0xECE5D8)),
        secondaryText: Color(light: Color(hex: 0x6F675B), dark: Color(hex: 0xA59C8D)),
        separator: Color(light: Color(hex: 0x1F1C17, opacity: 0.14), dark: Color(hex: 0xECE5D8, opacity: 0.14)),
        accent: Color(light: Color(hex: 0x9B2C1F), dark: Color(hex: 0xE0806F)),
        onAccent: Color(light: .white, dark: Color(hex: 0x1F0B07)),
        upload: Color(light: Color(hex: 0x6F675B), dark: Color(hex: 0xA59C8D)),
        download: Color(light: Color(hex: 0x1F1C17), dark: Color(hex: 0xECE5D8)),
        cornerRadius: 18,
        textDesign: .serif,
        numberDesign: .serif,
        forcedColorScheme: nil,
        usesGlass: false
    )

    static let radio = SkinTheme(
        id: .radio,
        background: Color(light: Color(hex: 0xE6E3DC), dark: Color(hex: 0x2A2926)),
        surface: Color(light: Color(hex: 0xF4F2ED), dark: Color(hex: 0x36342F)),
        elevatedSurface: Color(light: Color(hex: 0xD6D2C9), dark: Color(hex: 0x1F1E1B)),
        text: Color(light: Color(hex: 0x1A1A1A), dark: Color(hex: 0xECE8DF)),
        secondaryText: Color(light: Color(hex: 0x6F6A60), dark: Color(hex: 0xA8A295)),
        separator: Color(light: Color(hex: 0xB9B4A9), dark: Color(hex: 0x4A4741)),
        accent: Color(hex: 0xFF5A1F),
        onAccent: .white,
        upload: Color(hex: 0xFFA640),
        download: Color(hex: 0xFFA640),
        cornerRadius: 12,
        textDesign: .default,
        numberDesign: .monospaced,
        forcedColorScheme: nil,
        usesGlass: false
    )

    static let bento = SkinTheme(
        id: .bento,
        background: Color(light: Color(hex: 0xEFEFED), dark: Color(hex: 0x050505)),
        surface: Color(light: .white, dark: Color(hex: 0x161616)),
        elevatedSurface: Color(light: Color(hex: 0xEFEFED), dark: Color(hex: 0x222222)),
        text: Color(light: Color(hex: 0x0F0F0F), dark: Color(hex: 0xF2F2F2)),
        secondaryText: Color(light: Color(hex: 0x6B6B6B), dark: Color(hex: 0x9A9A9A)),
        separator: Color(light: Color(hex: 0xE3E3E0), dark: Color(hex: 0x2A2A2A)),
        accent: Color(light: Color(hex: 0xD71921), dark: Color(hex: 0xFF3B30)),
        onAccent: .white,
        upload: Color(light: Color(hex: 0x0F0F0F), dark: Color(hex: 0xF2F2F2)),
        download: Color(light: Color(hex: 0x0F0F0F), dark: Color(hex: 0xF2F2F2)),
        cornerRadius: 28,
        textDesign: .default,
        numberDesign: .monospaced,
        forcedColorScheme: nil,
        usesGlass: true
    )
}

struct SkinThemeKey: EnvironmentKey {
    static let defaultValue = SkinTheme.native
}

extension EnvironmentValues {
    var skinTheme: SkinTheme {
        get { self[SkinThemeKey.self] }
        set { self[SkinThemeKey.self] = newValue }
    }
}
