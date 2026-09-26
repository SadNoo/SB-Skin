import SwiftUI

/// Tab container for skins that draw their own tab bar.
///
/// Every visited tab stays alive (keeping scroll position and navigation), content scrolls under
/// the floating bar, and hidden tabs are removed from hit testing and accessibility.
struct SkinTabContainer<Tab: Hashable, Content: View, Bar: View>: View {
    @Binding var selection: Tab
    let tabs: [Tab]
    /// Space the bar occupies above the bottom safe area.
    var barHeight: CGFloat = 88
    @ViewBuilder var content: (Tab) -> Content
    @ViewBuilder var bar: () -> Bar

    @State private var visited: Set<Tab> = []

    var body: some View {
        ZStack(alignment: .bottom) {
            ForEach(tabs, id: \.self) { tab in
                if visited.contains(tab) || tab == selection {
                    content(tab)
                        .safeAreaInset(edge: .bottom, spacing: 0) {
                            Color.clear.frame(height: barHeight)
                        }
                        .opacity(tab == selection ? 1 : 0)
                        .allowsHitTesting(tab == selection)
                        .accessibilityHidden(tab != selection)
                }
            }
            bar()
        }
        .onAppear { visited.insert(selection) }
        .onChange(of: selection) { _, newValue in visited.insert(newValue) }
    }
}

/// One item of a custom tab bar.
struct SkinTabItem: Identifiable, Hashable {
    let id: String
    let title: String
    let symbol: String
}
