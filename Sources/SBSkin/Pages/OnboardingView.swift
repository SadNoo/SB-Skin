import SBSkinShared
import SwiftUI

/// First launch: “Choose your style”. Same features in every skin; changeable later in
/// Settings › Appearance. Skipping keeps the default (System Native).
struct OnboardingView: View {
    @Environment(SkinPreferences.self) private var preferences
    @Environment(\.skinConfiguration) private var configuration
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var index = 0
    @State private var dragOffset: CGFloat = 0

    private let skins = SkinID.allCases

    var body: some View {
        let current = skins[index]
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text(SkinL("Welcome to %@", configuration.appName))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(skin: "Choose your style")
                    .font(.largeTitle.weight(.heavy))
                Text(skin: "Every skin has the same features — it just looks and feels different. You can change it any time in Settings › Appearance.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 28)

            carousel
                .frame(maxHeight: .infinity)
                .padding(.vertical, 12)

            VStack(spacing: 4) {
                Text(current.displayName).font(.title2.weight(.heavy))
                Text(current.tagline).font(.subheadline)
                Text(SkinL("Best for: %@", current.audience)).font(.caption).foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
            .contentTransition(.opacity)
            .animation(.smooth, value: index)

            HStack(spacing: 4) {
                ForEach(skins.indices, id: \.self) { position in
                    Button {
                        withAnimation(.smooth) { index = position }
                    } label: {
                        Capsule()
                            .fill(position == index ? current.accent : Color.secondary.opacity(0.35))
                            .frame(width: position == index ? 20 : 8, height: 8)
                            .frame(width: 24, height: 28)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(skins[position].displayName))
                }
            }
            .padding(.vertical, 8)

            VStack(spacing: 6) {
                Button {
                    preferences.skin = current
                    preferences.hasChosenSkin = true
                } label: {
                    Text(SkinL("Use “%@”", current.displayName))
                        .font(.headline)
                        .frame(maxWidth: 420)
                        .frame(height: 52)
                }
                .buttonStyle(.glassProminent)
                .tint(current.accent)

                Button {
                    preferences.skin = .default
                    preferences.hasChosenSkin = true
                } label: {
                    Text(SkinL("Not now (use %@)", SkinID.default.displayName))
                        .font(.subheadline)
                        .frame(minHeight: 36)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        #if os(macOS)
        .frame(minWidth: 560, minHeight: 760)
        #endif
    }

    private var carousel: some View {
        GeometryReader { proxy in
            let height = proxy.size.height
            let width = height * 390 / 844
            HStack(spacing: 20) {
                ForEach(skins.indices, id: \.self) { position in
                    SkinThumbnail(skin: skins[position])
                        .frame(width: width, height: height)
                        .clipShape(RoundedRectangle(cornerRadius: width * 0.12, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: width * 0.12, style: .continuous)
                                .strokeBorder(position == index ? skins[position].accent : .clear, lineWidth: 3)
                        }
                        .shadow(color: .black.opacity(0.18), radius: 16, y: 8)
                        .scaleEffect(position == index ? 1 : 0.84)
                        .opacity(position == index ? 1 : 0.5)
                        .onTapGesture { withAnimation(.smooth) { index = position } }
                }
            }
            .offset(x: (proxy.size.width - width) / 2 - CGFloat(index) * (width + 20) + dragOffset)
            .gesture(
                DragGesture()
                    .onChanged { dragOffset = $0.translation.width }
                    .onEnded { value in
                        let threshold = width * 0.25
                        withAnimation(.smooth) {
                            if value.translation.width < -threshold { index = min(index + 1, skins.count - 1) }
                            if value.translation.width > threshold { index = max(index - 1, 0) }
                            dragOffset = 0
                        }
                    }
            )
            .animation(.smooth, value: index)
        }
    }
}
