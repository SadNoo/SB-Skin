import SBSkinShared
import SwiftUI
import WidgetKit
#if os(iOS)
    import ActivityKit
    import UIKit
#else
    import AppKit
#endif

/// Mirrors the store into the App Group (widgets) and a Live Activity (iOS).
struct SystemSurfacesSync: ViewModifier {
    let session: SkinSession
    @State private var lastWrite = Date.distantPast
    @State private var lastWidgetReload = Date.distantPast

    func body(content: Content) -> some View {
        let store = session.store
        content
            .onChange(of: store.status) { _, _ in sync(force: false) }
            .onChange(of: store.phase) { _, _ in sync(force: true) }
            .onChange(of: store.groups) { _, _ in sync(force: true) }
            .onChange(of: store.clashMode) { _, _ in sync(force: true) }
            .onChange(of: session.preferences.skin) { _, _ in sync(force: true) }
            .onAppear { sync(force: true) }
    }

    private func sync(force: Bool) {
        let now = Date()
        guard force || now.timeIntervalSince(lastWrite) >= 2 else { return }
        lastWrite = now
        let snapshot = makeSnapshot()
        if session.configuration.widgetSnapshots {
            SkinSharedStorage.writeSnapshot(snapshot)
            // Timelines have a budget; only ask for reloads on meaningful changes.
            if force || now.timeIntervalSince(lastWidgetReload) > 60 {
                lastWidgetReload = now
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
        #if os(iOS)
            if session.configuration.liveActivities {
                LiveActivityController.shared.update(snapshot: snapshot)
            }
        #endif
    }

    private func makeSnapshot() -> SkinWidgetSnapshot {
        let store = session.store
        let group = store.primaryGroup
        let node = store.currentNode
        let favorites = (group?.items ?? [])
            .filter { store.group($0.tag) == nil && $0.delay > 0 && $0.delay != .max }
            .sorted { $0.delay < $1.delay }
            .prefix(3)
            .map { SkinWidgetSnapshot.Node(tag: $0.tag, delay: $0.delay) }
        return SkinWidgetSnapshot(
            isRunning: store.isRunning,
            connectedSince: store.connectedSince,
            profileName: store.activeProfile?.name ?? "",
            groupTag: group?.tag ?? "",
            nodeTag: node?.tag ?? "",
            nodeDelay: node?.delay ?? 0,
            mode: store.clashMode,
            uplink: store.status.uplink,
            downlink: store.status.downlink,
            uplinkTotal: store.status.uplinkTotal,
            downlinkTotal: store.status.downlinkTotal,
            connections: store.status.totalConnections,
            memory: store.status.memory,
            downlinkHistory: Array(store.downlinkHistory.suffix(30)),
            favorites: Array(favorites),
            skin: session.preferences.skin,
            vocabulary: session.preferences.vocabulary,
            deepLinkScheme: session.configuration.deepLinkScheme,
            updatedAt: .now
        )
    }
}

#if os(iOS)
    /// Starts, updates and ends the Live Activity that mirrors the running service.
    @MainActor
    final class LiveActivityController {
        static let shared = LiveActivityController()
        private var activity: Activity<SkinActivityAttributes>?
        private var lastState: SkinActivityAttributes.ContentState?

        func update(snapshot: SkinWidgetSnapshot) {
            guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
            if activity == nil {
                activity = Activity<SkinActivityAttributes>.activities.first
            }
            if snapshot.isRunning {
                let state = SkinActivityAttributes.ContentState(snapshot: snapshot)
                guard state != lastState else { return }
                lastState = state
                let content = ActivityContent(state: state, staleDate: Date(timeIntervalSinceNow: 120))
                if let activity {
                    Task { await activity.update(content) }
                } else {
                    let attributes = SkinActivityAttributes(
                        profileName: snapshot.profileName,
                        skin: snapshot.skin,
                        vocabulary: snapshot.vocabulary,
                        deepLinkScheme: snapshot.deepLinkScheme
                    )
                    activity = try? Activity.request(attributes: attributes, content: content, pushType: nil)
                }
            } else if let activity {
                lastState = nil
                self.activity = nil
                Task { await activity.end(nil, dismissalPolicy: .immediate) }
            }
        }
    }
#endif

/// Switches the app icon when the skin changes, if the host ships alternate icons.
struct AlternateIconSync: ViewModifier {
    let session: SkinSession

    func body(content: Content) -> some View {
        content.onChange(of: session.preferences.skin) { _, skin in
            guard session.preferences.iconFollowsSkin, !session.configuration.alternateIcons.isEmpty else { return }
            let name = session.configuration.alternateIcons[skin]
            #if os(iOS)
                guard UIApplication.shared.supportsAlternateIcons, UIApplication.shared.alternateIconName != name else { return }
                UIApplication.shared.setAlternateIconName(name)
            #else
                if let name, let image = NSImage(named: name) {
                    NSApplication.shared.applicationIconImage = image
                } else {
                    NSApplication.shared.applicationIconImage = nil
                }
            #endif
        }
    }
}
