import SwiftUI

/// Every skin that ships in Skywave. The raw value is persisted; never rename a case.
public enum SkinID: String, CaseIterable, Codable, Sendable, Identifiable, Hashable {
    /// A · System native, Liquid Glass. The default skin.
    case native
    /// B · Dark instrument panel.
    case instrument
    /// C · Single-focus one-tap connect.
    case focus
    /// D · Places: where you are and how the road is.
    case places
    /// E · Transparency: where your traffic went.
    case lens
    /// F · One sentence: the interface nearly disappears.
    case sentence
    /// G · Radio: a device you can hold.
    case radio
    /// I · Bento: arrange your own panel.
    case bento
    /// J · Ink: an e-paper reader, black on paper, turned page by page.
    case ink
    /// K · Mart: a corner store where nodes are goods on the shelf.
    case mart

    public var id: String { rawValue }

    public static let `default`: SkinID = .native

    public var displayName: String {
        switch self {
        case .native: SharedL("System Native")
        case .instrument: SharedL("Instrument")
        case .focus: SharedL("One Tap")
        case .places: SharedL("Places")
        case .lens: SharedL("Transparent")
        case .sentence: SharedL("One Sentence")
        case .radio: SharedL("Radio")
        case .bento: SharedL("Bento")
        case .ink: SharedL("E-Ink")
        case .mart: SharedL("Corner Store")
        }
    }

    public var tagline: String {
        switch self {
        case .native: SharedL("Feels like Apple made it")
        case .instrument: SharedL("Every number, right in front of you")
        case .focus: SharedL("Open it, connect or disconnect")
        case .places: SharedL("Where you are, and how the road is")
        case .lens: SharedL("See which road every connection took")
        case .sentence: SharedL("The interface almost disappears")
        case .radio: SharedL("A device you can hold in your hand")
        case .bento: SharedL("Your panel, arranged your way")
        case .ink: SharedL("Calm as a page of paper")
        case .mart: SharedL("Pick a node like picking a snack")
        }
    }

    public var audience: String {
        switch self {
        case .native: SharedL("People who want it stable and familiar")
        case .instrument: SharedL("Power users who like live data")
        case .focus: SharedL("People who just want the network to work")
        case .places: SharedL("People who prefer plain words over jargon")
        case .lens: SharedL("People who want to understand routing rules")
        case .sentence: SharedL("People who like calm, beautiful typography")
        case .radio: SharedL("People who love tactile hardware")
        case .bento: SharedL("Tinkerers who want to customize")
        case .ink: SharedL("People who like quiet, readable screens")
        case .mart: SharedL("People who want it fun and friendly")
        }
    }

    /// A single accent color that represents the skin in pickers, widgets and Live Activities.
    public var accent: Color {
        switch self {
        case .native: Color(red: 0.04, green: 0.52, blue: 1.0)
        case .instrument: Color(red: 0.30, green: 0.79, blue: 0.94)
        case .focus: Color(red: 0.18, green: 0.42, blue: 0.31)
        case .places: Color(red: 0.91, green: 0.34, blue: 0.16)
        case .lens: Color(red: 0.26, green: 0.22, blue: 0.79)
        case .sentence: Color(red: 0.61, green: 0.17, blue: 0.12)
        case .radio: Color(red: 1.0, green: 0.35, blue: 0.12)
        case .bento: Color(red: 0.84, green: 0.10, blue: 0.13)
        case .ink: Color(red: 0.13, green: 0.13, blue: 0.13)
        case .mart: Color(red: 0.88, green: 0.27, blue: 0.17)
        }
    }

    /// SF Symbol used when a skin needs a tiny glyph (menus, command palette).
    public var symbol: String {
        switch self {
        case .native: "apple.logo"
        case .instrument: "gauge.with.dots.needle.67percent"
        case .focus: "power.circle"
        case .places: "map"
        case .lens: "point.topleft.down.to.point.bottomright.curvepath"
        case .sentence: "text.quote"
        case .radio: "radio"
        case .bento: "square.grid.2x2"
        case .ink: "book.closed"
        case .mart: "basket"
        }
    }
}
