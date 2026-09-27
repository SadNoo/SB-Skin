import SwiftUI

extension View {
    /// Presents router sheets (nodes, profiles, appearance, connections, logs, more).
    /// A skin can swap in its own node picker; everything else is shared.
    func skinSheets(nodePicker: ((String?) -> AnyView)? = nil) -> some View {
        modifier(SkinSheetsModifier(nodePicker: nodePicker))
    }
}

private struct SkinSheetsModifier: ViewModifier {
    @Environment(SkinRouter.self) private var router
    let nodePicker: ((String?) -> AnyView)?

    func body(content: Content) -> some View {
        @Bindable var router = router
        content.sheet(item: $router.sheet) { sheet in
            SheetContainer(sheet: sheet, focusedGroup: router.focusedGroup, nodePicker: nodePicker)
        }
    }
}

private struct SheetContainer: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.skinTheme) private var theme
    let sheet: SkinRouter.Sheet
    let focusedGroup: String?
    let nodePicker: ((String?) -> AnyView)?

    var body: some View {
        Group {
            if sheet == .nodes, let nodePicker {
                nodePicker(focusedGroup)
            } else {
                NavigationStack {
                    page
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button(SkinL("Done")) { dismiss() }
                            }
                        }
                }
            }
        }
        .presentationDetents(sheet == .nodes || sheet == .profiles ? [.medium, .large] : [.large])
        .presentationBackground(theme.background)
        #if os(macOS)
            .frame(minWidth: 520, minHeight: 560)
        #endif
    }

    @ViewBuilder
    private var page: some View {
        switch sheet {
        case .nodes: NodesPage(focusedGroup: focusedGroup)
        case .profiles: ProfilesPage()
        case .appearance: AppearancePage()
        case .connections: ConnectionsPage()
        case .logs: LogsPage()
        case .more: MorePage()
        }
    }
}
