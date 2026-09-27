import SkywaveShared
import SwiftUI

/// Every outbound group with its members: select, URL-test, expand/collapse.
/// Shared by all skins (themed); the Native skin uses it as its Groups tab.
struct NodesPage: View {
    @Environment(SkinStore.self) private var store
    @Environment(\.skinTheme) private var theme
    @Environment(\.horizontalSizeClass) private var sizeClass
    var focusedGroup: String?
    var showsTitle = true

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    if store.groups.isEmpty {
                        emptyState
                    }
                    ForEach(store.groups) { group in
                        GroupSection(group: group)
                            .id(group.tag)
                    }
                }
                .padding(.horizontal, sizeClass == .regular ? 24 : 16)
                .padding(.vertical, 12)
                .frame(maxWidth: 1100)
                .frame(maxWidth: .infinity)
            }
            .onAppear {
                if let focusedGroup {
                    proxy.scrollTo(focusedGroup, anchor: .top)
                }
            }
        }
        .background(theme.background)
        .navigationTitle(showsTitle ? SkinL("Outbound Groups") : "")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    store.urlTestAll()
                } label: {
                    if store.isTestingAny {
                        ProgressView()
                    } else {
                        Label(SkinL("Test All"), systemImage: "bolt")
                    }
                }
                .disabled(store.groups.isEmpty || store.isTestingAny)
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        ContentUnavailableView {
            Label(SkinL("No outbound groups"), systemImage: "square.grid.3x3")
        } description: {
            Text(store.isRunning ? SkinL("This profile has no selectable groups.") : SkinL("Start the service to see groups."))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}

/// One group: header plus member list or grid.
struct GroupSection: View {
    @Environment(SkinStore.self) private var store
    @Environment(\.skinTheme) private var theme
    @Environment(\.horizontalSizeClass) private var sizeClass
    let group: SkinOutboundGroup

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            if group.isExpanded {
                if sizeClass == .regular {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 10)], spacing: 10) {
                        ForEach(group.items) { item in
                            NodeTile(group: group, item: item)
                        }
                    }
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(group.items.enumerated()), id: \.element.id) { index, item in
                            NodeRow(group: group, item: item)
                            if index < group.items.count - 1 {
                                Divider().overlay(theme.separator).padding(.leading, 46)
                            }
                        }
                    }
                    .background(theme.surface, in: RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous))
                }
            } else {
                collapsedSummary
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Button {
                withAnimation(.snappy) { store.setExpanded(group.tag, !group.isExpanded) }
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(group.tag)
                        .font(theme.font(.title3, weight: .bold))
                        .foregroundStyle(theme.text)
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(theme.secondaryText)
                        .rotationEffect(.degrees(group.isExpanded ? 0 : -90))
                }
            }
            .buttonStyle(.plain)
            Text(verbatim: "\(group.displayType) · \(group.items.count)")
                .font(.footnote)
                .foregroundStyle(theme.secondaryText)
            Spacer()
            Button {
                store.urlTest(group.tag)
            } label: {
                if store.testingGroups.contains(group.tag) {
                    ProgressView().controlSize(.small)
                } else {
                    Label(SkinL("Test"), systemImage: "bolt")
                        .labelStyle(.iconOnly)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.accent)
                }
            }
            .buttonStyle(.plain)
            .frame(minWidth: 44, minHeight: 32)
            .accessibilityLabel(Text(skin: "Test latency"))
        }
        .padding(.horizontal, 4)
    }

    private var collapsedSummary: some View {
        let resolved = store.resolvedNode(in: group)
        return Button {
            withAnimation(.snappy) { store.setExpanded(group.tag, true) }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(resolved.node?.tag ?? group.selected)
                        .font(theme.font(.body))
                        .foregroundStyle(theme.text)
                    if !resolved.via.isEmpty {
                        Text(verbatim: "\(group.selected) →")
                            .font(.caption)
                            .foregroundStyle(theme.secondaryText)
                    }
                }
                Spacer()
                if let node = resolved.node {
                    LatencyText(delay: node.delay)
                }
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(theme.secondaryText.opacity(0.6))
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 52)
            .background(theme.surface, in: RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous))
        }
        .buttonStyle(SkinPressStyle(scale: 0.99))
    }
}

/// Compact list row.
struct NodeRow: View {
    @Environment(SkinStore.self) private var store
    @Environment(\.skinTheme) private var theme
    let group: SkinOutboundGroup
    let item: SkinOutbound

    var body: some View {
        let selected = item.tag == group.selected
        Button {
            store.select(item.tag, in: group.tag)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "checkmark")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(theme.accent)
                    .opacity(selected ? 1 : 0)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.tag)
                        .font(theme.font(.body, weight: selected ? .semibold : .regular))
                        .foregroundStyle(theme.text)
                        .lineLimit(1)
                    Text(item.type)
                        .font(.caption)
                        .foregroundStyle(theme.secondaryText)
                }
                Spacer(minLength: 8)
                LatencyText(delay: item.delay)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!group.selectable)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Grid tile for wide layouts.
struct NodeTile: View {
    @Environment(SkinStore.self) private var store
    @Environment(\.skinTheme) private var theme
    let group: SkinOutboundGroup
    let item: SkinOutbound

    var body: some View {
        let selected = item.tag == group.selected
        Button {
            store.select(item.tag, in: group.tag)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(item.tag)
                        .font(theme.font(.subheadline, weight: .semibold))
                        .foregroundStyle(theme.text)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    if selected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(theme.accent)
                    }
                }
                HStack {
                    Text(item.type)
                        .font(.caption)
                        .foregroundStyle(theme.secondaryText)
                    Spacer()
                    LatencyText(delay: item.delay, font: .caption.weight(.semibold))
                }
            }
            .padding(12)
            .background(
                selected ? theme.accent.opacity(0.1) : theme.surface,
                in: RoundedRectangle(cornerRadius: min(theme.cornerRadius, 16), style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: min(theme.cornerRadius, 16), style: .continuous)
                    .strokeBorder(selected ? theme.accent : .clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(SkinPressStyle())
        .disabled(!group.selectable)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
