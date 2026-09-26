import SwiftUI

/// Quick profile switcher. Full management (create, import, edit, share) stays in the
/// upstream profile screen provided by the host.
struct ProfilesPage: View {
    @Environment(SkinStore.self) private var store
    @Environment(\.skinTheme) private var theme
    @Environment(\.skinConfiguration) private var configuration
    @Environment(\.dismiss) private var dismiss
    var dismissesOnSelect = true

    var body: some View {
        List {
            Section {
                ForEach(store.profiles) { profile in
                    Button {
                        store.selectProfile(profile.id)
                        if dismissesOnSelect { dismiss() }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: profile.isRemote ? "icloud" : "doc.text")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(theme.accent)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(profile.name)
                                    .font(theme.font(.body, weight: .semibold))
                                    .foregroundStyle(theme.text)
                                Text(profileSubtitle(profile))
                                    .font(.caption)
                                    .foregroundStyle(theme.secondaryText)
                            }
                            Spacer()
                            if profile.id == store.selectedProfileID {
                                if store.isSwitchingProfile {
                                    ProgressView()
                                } else {
                                    Image(systemName: "checkmark").font(.body.weight(.bold)).foregroundStyle(theme.accent)
                                }
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(theme.surface)
                    .accessibilityAddTraits(profile.id == store.selectedProfileID ? .isSelected : [])
                }
            } footer: {
                if store.isRunning {
                    Text(skin: "Switching reloads the service with the new profile.")
                }
            }
            if let profiles = configuration.hostPages.profiles {
                Section {
                    NavigationLink {
                        profiles()
                    } label: {
                        Label(SkinL("Manage Profiles"), systemImage: "slider.horizontal.3")
                    }
                    .listRowBackground(theme.surface)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(theme.background)
        .navigationTitle(SkinL("Profiles"))
    }

    private func profileSubtitle(_ profile: SkinProfile) -> String {
        if profile.isRemote {
            if let date = profile.lastUpdated {
                return SkinL("Remote · updated %@", date.formatted(.relative(presentation: .named)))
            }
            return SkinL("Remote")
        }
        return SkinL("Local")
    }
}
