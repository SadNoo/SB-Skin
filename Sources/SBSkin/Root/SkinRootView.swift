import SBSkinShared
import SwiftUI

/// The host's single entry point. Shows the chosen skin, first-launch onboarding, alerts,
/// the command palette, and keeps widgets / Live Activities in sync.
public struct SkinRootView: View {
    @Environment(\.scenePhase) private var scenePhase
    private let session: SkinSession

    public init(session: SkinSession) {
        self.session = session
    }

    public var body: some View {
        let preferences = session.preferences
        let store = session.store
        let theme = SkinTheme.of(preferences.skin)
        @Bindable var router = session.router

        SkinCanvas(skin: preferences.skin)
            .id(preferences.skin)
            .transition(.opacity)
            .animation(.smooth(duration: 0.35), value: preferences.skin)
            .environment(store)
            .environment(preferences)
            .environment(session.router)
            .environment(\.skinConfiguration, session.configuration)
            .preferredColorScheme(theme.forcedColorScheme ?? preferences.appearance.colorScheme)
            .overlay {
                if router.showsCommandPalette {
                    CommandPalette(isPresented: $router.showsCommandPalette)
                        .environment(store)
                        .environment(preferences)
                        .environment(session.router)
                        .environment(\.skinTheme, theme)
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                if let remote = store.remoteName {
                    RemoteBanner(name: remote)
                        .environment(\.skinTheme, theme)
                }
            }
            .background { keyboardShortcuts }
            .alert(
                store.alert?.title ?? "",
                isPresented: Binding(get: { store.alert != nil }, set: { if !$0 { store.alert = nil } }),
                presenting: store.alert
            ) { _ in
                Button(SkinL("OK"), role: .cancel) { store.alert = nil }
            } message: { alert in
                Text(alert.message)
            }
            #if os(iOS)
            .fullScreenCover(isPresented: onboardingBinding) {
                OnboardingView()
                    .environment(preferences)
                    .environment(\.skinConfiguration, session.configuration)
            }
            #else
            .sheet(isPresented: onboardingBinding) {
                OnboardingView()
                    .environment(preferences)
                    .environment(\.skinConfiguration, session.configuration)
            }
            #endif
            .onOpenURL { url in
                session.handle(url)
            }
            .onAppear { store.backend.activate() }
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .active: store.backend.activate()
                case .background: store.backend.deactivate()
                default: break
                }
            }
            .modifier(SystemSurfacesSync(session: session))
            .modifier(AlternateIconSync(session: session))
    }

    private var onboardingBinding: Binding<Bool> {
        Binding(
            get: { !session.preferences.hasChosenSkin },
            set: { if !$0 { session.preferences.hasChosenSkin = true } }
        )
    }

    /// ⌘K command palette, ⌃⌘S cycle skins. Works with hardware keyboards on iPad too.
    private var keyboardShortcuts: some View {
        ZStack {
            Button("") { session.router.showsCommandPalette.toggle() }
                .keyboardShortcut("k", modifiers: .command)
            Button("") {
                let all = SkinID.allCases
                let next = all[(all.firstIndex(of: session.preferences.skin)! + 1) % all.count]
                session.preferences.skin = next
            }
            .keyboardShortcut("s", modifiers: [.command, .control])
        }
        .opacity(0)
        .accessibilityHidden(true)
    }
}

/// Shown on top of every skin while controlling another device.
private struct RemoteBanner: View {
    @Environment(SkinStore.self) private var store
    @Environment(\.skinTheme) private var theme
    let name: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "antenna.radiowaves.left.and.right")
            Text(SkinL("Controlling %@", name)).lineLimit(1)
            Spacer()
            Button(SkinL("Disconnect")) { store.disconnectRemote() }
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .font(.subheadline.weight(.semibold))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .glassEffect(.regular.tint(theme.accent.opacity(0.2)), in: Capsule())
        .padding(.horizontal, 12)
        .padding(.top, 4)
    }
}

/// Renders one skin with its theme. Used by the root and by thumbnails.
struct SkinCanvas: View {
    let skin: SkinID
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = SkinTheme.of(skin)
        content
            .environment(\.skinTheme, theme)
            .environment(\.colorScheme, theme.forcedColorScheme ?? colorScheme)
            .tint(theme.accent)
            .fontDesign(theme.textDesign == .default ? nil : theme.textDesign)
            .background(theme.background.ignoresSafeArea())
    }

    @ViewBuilder
    private var content: some View {
        switch skin {
        case .native: NativeSkin()
        case .instrument: InstrumentSkin()
        case .focus: FocusSkin()
        case .places: PlacesSkin()
        case .lens: LensSkin()
        case .sentence: SentenceSkin()
        case .radio: RadioSkin()
        case .bento: BentoSkin()
        }
    }
}

#Preview("Live") {
    SkinRootView(session: .preview(.live, skin: .native))
}
