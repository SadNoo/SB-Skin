import SwiftUI

/// A floating Liquid Glass tab bar that skins style through a few knobs.
struct FloatingTabBar<Tab: Hashable>: View {
    @Environment(\.skinTheme) private var theme
    @Binding var selection: Tab
    let items: [(tab: Tab, title: String, symbol: String)]
    var showsTitles = true
    var selectedTint: Color?
    var selectedBackground: Color?
    var foreground: Color?
    var height: CGFloat = 62
    var horizontalPadding: CGFloat = 16
    var badge: (Tab) -> Int = { _ in 0 }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                let selected = item.tab == selection
                Button {
                    withAnimation(.snappy(duration: 0.25)) { selection = item.tab }
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: item.symbol)
                            .font(.system(size: showsTitles ? 19 : 20, weight: .semibold))
                            .overlay(alignment: .topTrailing) {
                                let count = badge(item.tab)
                                if count > 0 {
                                    Text(verbatim: "\(count)")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 5)
                                        .frame(minWidth: 16, minHeight: 16)
                                        .background(Color.red, in: Capsule())
                                        .offset(x: 10, y: -6)
                                }
                            }
                        if showsTitles {
                            Text(item.title).font(.system(size: 10, weight: .semibold))
                        }
                    }
                    .foregroundStyle(selected ? (selectedTint ?? theme.accent) : (foreground ?? theme.text))
                    .frame(maxWidth: .infinity)
                    .frame(height: height - 10)
                    .background {
                        if selected {
                            Capsule().fill(selectedBackground ?? theme.accent.opacity(0.14))
                        }
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(item.title))
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(.horizontal, 5)
        .frame(height: height)
        .glassEffect(.regular, in: Capsule())
        .padding(.horizontal, horizontalPadding)
        .padding(.bottom, 8)
    }
}
