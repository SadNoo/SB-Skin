import Foundation

/// Looks up a string in SBSkinShared's own string catalog.
/// Keys are the English source text; translations live in Resources/Localizable.xcstrings.
public func SharedL(_ key: String) -> String {
    String(localized: String.LocalizationValue(key), bundle: .module)
}

/// Same as ``SharedL(_:)`` with `%@` / `%lld` style arguments.
public func SharedL(_ key: String, _ arguments: CVarArg...) -> String {
    String(format: SharedL(key), locale: .current, arguments: arguments)
}
