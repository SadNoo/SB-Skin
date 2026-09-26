// Signature stubs of the upstream `ApplicationLibrary` framework.
// Only declarations used by Integration/Apple. No behavior.

import Foundation
import Library
import SwiftUI

@MainActor
open class BaseViewModel: ObservableObject {
    @Published public var alert: AlertState?
    @Published public var isLoading = false
    public init() {}
}

public struct ProfilePreview: Identifiable, Hashable {
    public let id: Int64
    public let name: String
}

@MainActor
public final class DashboardViewModel: BaseViewModel {
    @Published public var profileList: [ProfilePreview] = []
    @Published public var selectedProfileID: Int64 = 0
    public func setEnvironments(_ environments: ExtensionEnvironments) {}
    public func reload() async {}
}

public extension ExtensionProfile {
    nonisolated func checkLastDisconnectError() async -> AlertState? { nil }
}

public struct ProfileCard: View {
    public init(profileList: Binding<[ProfilePreview]>, selectedProfileID: Binding<Int64>) {}
    public var body: some View { EmptyView() }
}

public struct ToolsView: View {
    public init() {}
    public var body: some View { EmptyView() }
}

public struct SettingView: View {
    public init() {}
    public var body: some View { EmptyView() }
}

public struct RemoteControlView: View {
    public init() {}
    public var body: some View { EmptyView() }
}

public enum SheetSize {
    case large
}

@MainActor
public struct NavigationSheet<Content: View>: View {
    public init(
        title: String? = nil,
        size: SheetSize = .large,
        showDoneButton: Bool = false,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {}

    public var body: some View { EmptyView() }
}

public struct NewProfileView: View {
    public struct ImportRequest: Codable, Hashable, Identifiable {
        public var id: String { url }
        public let name: String
        public let url: String
        public init(name: String, url: String) {
            self.name = name
            self.url = url
        }
    }

    public struct LocalImportRequest: Hashable {}

    public init(_ importRequest: ImportRequest? = nil, localImportRequest: LocalImportRequest? = nil, onSuccess: ((Profile) async -> Void)? = nil) {}
    public var body: some View { EmptyView() }
}
