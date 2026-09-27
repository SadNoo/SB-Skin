import Foundation
import SwiftUI

/// Looks up a string in Skywave's string catalog. Keys are the English source text.
func SkinL(_ key: String) -> String {
    String(localized: String.LocalizationValue(key), bundle: .module)
}

/// Same as ``SkinL(_:)`` with printf-style arguments (`%@`, `%lld`).
func SkinL(_ key: String, _ arguments: CVarArg...) -> String {
    String(format: SkinL(key), locale: .current, arguments: arguments)
}

extension Text {
    /// `Text(skin: "Connections")` — localized from the Skywave bundle.
    init(skin key: String) {
        self.init(SkinL(key))
    }
}
