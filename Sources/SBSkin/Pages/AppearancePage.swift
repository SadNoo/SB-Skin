import SBSkinShared
import SwiftUI

/// Settings › Appearance: pick a skin (live thumbnails), vocabulary, color scheme, icon, sync.
struct AppearancePage: View {
    @Environment(SkinPreferences.self) private var preferences
    @Environment(\.skinTheme) private var theme
    @Environment(\.skinConfiguration) private var configuration
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        @Bindable var preferences = preferences
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                sectionTitle(SkinL("Interface Skin"))
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(SkinID.allCases) { skin in
                        SkinChoiceButton(skin: skin, selected: preferences.skin == skin) {
                            withAnimation(.smooth(duration: 0.35)) { preferences.skin = skin }
                        }
                    }
                }
                .padding(14)
                .background(theme.surface, in: RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous))

                Text(skin: "Every skin has exactly the same features. Settings, profiles and tools keep one shared layout and follow the skin's colors.")
                    .font(.footnote)
                    .foregroundStyle(theme.secondaryText)
                    .padding(.horizontal, 6)

                VStack(spacing: 0) {
                    pickerRow(SkinL("Color Mode")) {
                        Picker(SkinL("Color Mode"), selection: $preferences.appearance) {
                            ForEach(SkinAppearance.allCases) { Text($0.displayName).tag($0) }
                        }
                        .disabled(SkinTheme.of(preferences.skin).forcedColorScheme != nil)
                    }
                    divider
                    pickerRow(SkinL("Wording")) {
                        Picker(SkinL("Wording"), selection: Binding(
                            get: { preferences.vocabulary },
                            set: { preferences.vocabularyOverride = $0 == preferences.skin.defaultVocabulary ? nil : $0 }
                        )) {
                            ForEach(SkinVocabulary.allCases) { Text($0.displayName).tag($0) }
                        }
                    }
                    if !configuration.alternateIcons.isEmpty {
                        divider
                        Toggle(SkinL("App Icon Follows Skin"), isOn: $preferences.iconFollowsSkin)
                            .padding(.horizontal, 16).frame(minHeight: 48)
                    }
                    if configuration.syncWithICloud {
                        divider
                        Toggle(SkinL("Sync Skin Across Devices"), isOn: $preferences.syncAcrossDevices)
                            .padding(.horizontal, 16).frame(minHeight: 48)
                    }
                }
                .foregroundStyle(theme.text)
                .background(theme.surface, in: RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous))

                if SkinTheme.of(preferences.skin).forcedColorScheme != nil {
                    Text(skin: "This skin is designed for one color mode only.")
                        .font(.footnote)
                        .foregroundStyle(theme.secondaryText)
                        .padding(.horizontal, 6)
                }
                #if os(macOS)
                    Text(skin: "Tip: press ⌃⌘S to cycle through skins, ⌘K for the command palette.")
                        .font(.footnote)
                        .foregroundStyle(theme.secondaryText)
                        .padding(.horizontal, 6)
                #endif
            }
            .padding(16)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(theme.background)
        .navigationTitle(SkinL("Appearance"))
    }

    private var columns: [GridItem] {
        let count = sizeClass == .regular ? 4 : 4
        return Array(repeating: GridItem(.flexible(), spacing: 10, alignment: .top), count: count)
    }

    private var divider: some View {
        Divider().overlay(theme.separator).padding(.leading, 16)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(theme.secondaryText)
            .padding(.horizontal, 6)
    }

    private func pickerRow(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        HStack {
            Text(title)
            Spacer()
            content().labelsHidden().fixedSize()
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 48)
    }
}

/// Thumbnail + name; used in the Appearance grid.
struct SkinChoiceButton: View {
    @Environment(\.skinTheme) private var theme
    let skin: SkinID
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                SkinThumbnail(skin: skin)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(selected ? theme.accent : theme.separator, lineWidth: selected ? 3 : 1)
                    }
                    .shadow(color: .black.opacity(selected ? 0.16 : 0.06), radius: selected ? 8 : 3, y: 3)
                Text(skin.displayName)
                    .font(.caption.weight(selected ? .bold : .medium))
                    .foregroundStyle(selected ? theme.accent : theme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .buttonStyle(SkinPressStyle())
        .accessibilityLabel(Text(skin.displayName))
        .accessibilityHint(Text(skin.tagline))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
