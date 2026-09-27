import SwiftUI

extension View {
    /// Forces light or dark on the whole window (and everything it presents), or follows the
    /// system for `nil`. `preferredColorScheme(nil)` does not reliably hand control back to the
    /// system once a skin has forced a scheme — sheets stayed dark after leaving the
    /// Instrument skin — so this sets the window's own override instead.
    func windowColorScheme(_ scheme: ColorScheme?) -> some View {
        background(WindowAppearanceView(scheme: scheme).frame(width: 0, height: 0).accessibilityHidden(true))
    }
}

#if os(iOS)
    private struct WindowAppearanceView: UIViewRepresentable {
        let scheme: ColorScheme?

        func makeUIView(context: Context) -> Probe { Probe() }

        func updateUIView(_ view: Probe, context: Context) {
            view.style = switch scheme {
            case .dark: .dark
            case .light: .light
            default: .unspecified
            }
        }

        final class Probe: UIView {
            var style: UIUserInterfaceStyle = .unspecified {
                didSet { apply() }
            }

            override func didMoveToWindow() {
                super.didMoveToWindow()
                apply()
            }

            private func apply() {
                guard let window, window.overrideUserInterfaceStyle != style else { return }
                window.overrideUserInterfaceStyle = style
            }
        }
    }

#elseif os(macOS)
    private struct WindowAppearanceView: NSViewRepresentable {
        let scheme: ColorScheme?

        func makeNSView(context: Context) -> Probe { Probe() }

        func updateNSView(_ view: Probe, context: Context) {
            view.appearanceName = switch scheme {
            case .dark: .darkAqua
            case .light: .aqua
            default: nil
            }
        }

        final class Probe: NSView {
            var appearanceName: NSAppearance.Name? {
                didSet { apply() }
            }

            override func viewDidMoveToWindow() {
                super.viewDidMoveToWindow()
                apply()
            }

            private func apply() {
                guard let window else { return }
                let appearance = appearanceName.flatMap(NSAppearance.init(named:))
                if window.appearance?.name != appearance?.name {
                    window.appearance = appearance
                }
            }
        }
    }
#endif
