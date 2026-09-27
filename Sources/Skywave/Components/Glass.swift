import SwiftUI

extension View {
    /// Liquid Glass background in the given shape.
    func skinGlass(in shape: some Shape = Capsule(), tint: Color? = nil, interactive: Bool = false) -> some View {
        glassEffect(Glass.regular.tint(tint).interactive(interactive), in: shape)
    }

    /// Opaque card background using the active theme's surface color.
    func skinCard(_ theme: SkinTheme, radius: CGFloat? = nil, padding: CGFloat? = 16) -> some View {
        modifier(SkinCardModifier(theme: theme, radius: radius ?? theme.cornerRadius, padding: padding))
    }

    /// Makes a whole row tappable without changing its look.
    func skinTappable(_ action: @escaping () -> Void) -> some View {
        contentShape(Rectangle()).onTapGesture(perform: action)
    }
}

private struct SkinCardModifier: ViewModifier {
    let theme: SkinTheme
    let radius: CGFloat
    let padding: CGFloat?

    func body(content: Content) -> some View {
        content
            .padding(padding ?? 0)
            .background(theme.surface, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

/// A plain button style that dims on press; used for custom-drawn controls.
struct SkinPressStyle: ButtonStyle {
    var scale: CGFloat = 0.97

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: configuration.isPressed)
    }
}
