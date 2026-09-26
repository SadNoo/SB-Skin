import SwiftUI

extension View {
    /// Keeps the connection stream open while this view is on screen.
    func subscribesToConnections(_ store: SkinStore) -> some View {
        modifier(ConnectionSubscription(store: store))
    }

    /// Keeps the log stream open while this view is on screen.
    func subscribesToLogs(_ store: SkinStore) -> some View {
        modifier(LogSubscription(store: store))
    }
}

private struct ConnectionSubscription: ViewModifier {
    let store: SkinStore
    @State private var active = false

    func body(content: Content) -> some View {
        content
            .onAppear {
                guard !active else { return }
                active = true
                store.retainConnections()
            }
            .onDisappear {
                guard active else { return }
                active = false
                store.releaseConnections()
            }
    }
}

private struct LogSubscription: ViewModifier {
    let store: SkinStore
    @State private var active = false

    func body(content: Content) -> some View {
        content
            .onAppear {
                guard !active else { return }
                active = true
                store.retainLogs()
            }
            .onDisappear {
                guard active else { return }
                active = false
                store.releaseLogs()
            }
    }
}
