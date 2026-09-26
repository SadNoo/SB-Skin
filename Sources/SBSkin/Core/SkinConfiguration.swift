import SBSkinShared
import SwiftUI

/// What the host app provides to the skins: its name, deep-link scheme and the upstream
/// screens that every skin reuses unchanged (tools, full settings, profile management…).
///
/// Skins only redesign the everyday screens. Deep pages keep the upstream implementation so
/// that no feature is lost; they inherit the current skin's tint and color scheme.
public struct SkinConfiguration {
    /// Name shown in the UI. Defaults to the host bundle's display name, never “sing-box”.
    public var appName: String
    /// The host app's URL scheme, used by widgets and Live Activities to deep-link back.
    public var deepLinkScheme: String?
    /// Alternate app icon names per skin (optional). When empty the “App icon follows skin”
    /// setting is hidden.
    public var alternateIcons: [SkinID: String]
    /// Sync the chosen skin across devices with iCloud key-value storage. Requires the
    /// `com.apple.developer.ubiquity-kvstore-identifier` entitlement in the host.
    public var syncWithICloud: Bool
    /// Drive a Live Activity while the service runs (iOS). Requires `NSSupportsLiveActivities`.
    public var liveActivities: Bool
    /// Write a snapshot to the App Group so widgets can render.
    public var widgetSnapshots: Bool

    public var hostPages: SkinHostPages

    public init(
        appName: String = SkinConfiguration.bundleDisplayName,
        deepLinkScheme: String? = nil,
        alternateIcons: [SkinID: String] = [:],
        syncWithICloud: Bool = false,
        liveActivities: Bool = true,
        widgetSnapshots: Bool = true,
        hostPages: SkinHostPages = SkinHostPages()
    ) {
        self.appName = appName
        self.deepLinkScheme = deepLinkScheme
        self.alternateIcons = alternateIcons
        self.syncWithICloud = syncWithICloud
        self.liveActivities = liveActivities
        self.widgetSnapshots = widgetSnapshots
        self.hostPages = hostPages
    }

    public static var bundleDisplayName: String {
        let bundle = Bundle.main
        return (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? "App"
    }
}

/// Upstream screens injected by the host. Any page left `nil` is hidden from the skins.
public struct SkinHostPages {
    /// Profile list: create, import, edit, share, update, delete.
    public var profiles: (() -> AnyView)?
    /// Tools: network quality, STUN, Tailscale, SSH terminal, USB/IP, OpenVPN, reports…
    public var tools: (() -> AnyView)?
    /// The full upstream settings (app, core, packet tunnel, on-demand, profile override…).
    public var settings: (() -> AnyView)?
    /// Remote control of another device (optional).
    public var remoteControl: (() -> AnyView)?
    /// Badge shown on the tools entry (unread crash reports, Taildrop…).
    public var toolsBadge: () -> Int

    public init(
        profiles: (() -> AnyView)? = nil,
        tools: (() -> AnyView)? = nil,
        settings: (() -> AnyView)? = nil,
        remoteControl: (() -> AnyView)? = nil,
        toolsBadge: @escaping () -> Int = { 0 }
    ) {
        self.profiles = profiles
        self.tools = tools
        self.settings = settings
        self.remoteControl = remoteControl
        self.toolsBadge = toolsBadge
    }
}

struct SkinConfigurationKey: EnvironmentKey {
    static let defaultValue = SkinConfiguration()
}

extension EnvironmentValues {
    var skinConfiguration: SkinConfiguration {
        get { self[SkinConfigurationKey.self] }
        set { self[SkinConfigurationKey.self] = newValue }
    }
}
