import Foundation

/// The only way skins talk to the proxy core.
///
/// Two implementations exist:
/// - `UpstreamSkinBackend` in `Integration/Apple` bridges the upstream sing-box Apple client
///   (CommandClient, ExtensionProfile, CommandTarget). It is compiled inside the host app.
/// - ``MockSkinBackend`` feeds realistic sample data for previews, the demo app and
///   skin thumbnails.
///
/// A backend pushes state into the ``SkinStore`` it is attached to, and performs actions when
/// the store asks. Every action maps 1:1 to something the upstream client already does, so a
/// skin can never add or remove functionality.
@MainActor
public protocol SkinBackend: AnyObject {
    /// Called once when the store is created. Keep a weak reference and push state into it.
    func attach(to store: SkinStore)

    /// The UI became visible (or visible again after returning from background).
    func activate()
    /// The UI went to background.
    func deactivate()

    func startService() async throws
    func stopService() async throws

    func selectProfile(_ id: Int64) async throws

    func selectOutbound(group: String, outbound: String) async throws
    /// Runs a URL test for a whole group.
    func urlTest(group: String) async throws
    func setGroupExpanded(_ group: String, expanded: Bool) async throws

    func setClashMode(_ mode: String) async throws
    func setSystemProxyEnabled(_ enabled: Bool) async throws

    func closeConnection(id: String) async throws
    func closeAllConnections() async throws

    func clearLogs() async throws

    /// Connection tracking is a separate subscription upstream; only keep it open while a
    /// page that shows connections is on screen.
    func setConnectionsSubscribed(_ subscribed: Bool)
    /// Log streaming is only needed while a log view is visible.
    func setLogsSubscribed(_ subscribed: Bool)
}
