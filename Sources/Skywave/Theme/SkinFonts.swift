import CoreText
import SwiftUI

/// Fonts bundled with Skywave.
///
/// `SkywaveDots-Bold.ttf` is a modified version of Doto (Copyright 2024 The Doto Project Authors,
/// https://github.com/oliverlalan/Doto): the variable font pinned to weight 820 / roundness 0,
/// subset to ASCII and renamed. It remains under the SIL Open Font License 1.1 — see
/// Resources/Fonts/OFL.txt.
enum SkinFonts {
    static let dotsPostScriptName = "SkywaveDots-Bold"

    /// Registers the bundled font with the process once.
    private static let registered: Bool = {
        guard let url = Bundle.module.url(forResource: dotsPostScriptName, withExtension: "ttf") else {
            return false
        }
        var error: Unmanaged<CFError>?
        if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
            // `alreadyRegistered` is expected when several scenes start; anything else means the
            // font is unusable and we fall back to the system font.
            let code = (error?.takeRetainedValue()).map { CFErrorGetCode($0) } ?? 0
            return code == CTFontManagerError.alreadyRegistered.rawValue
        }
        return true
    }()

    /// Dot-matrix numerals; falls back to a heavy monospaced system font.
    /// Note: do not apply `.fontDesign(_:)` above text using this font — SwiftUI then swaps
    /// custom fonts for the system font.
    static func dot(_ size: CGFloat) -> Font {
        return registered ? Font.custom(dotsPostScriptName, fixedSize: size) : Font.system(size: size, weight: .black, design: .monospaced)
    }
}
