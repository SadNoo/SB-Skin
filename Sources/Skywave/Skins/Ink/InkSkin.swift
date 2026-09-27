import SkywaveShared
import SwiftUI

/// J · E-Ink. An e-paper reader: black ink on warm gray paper, serif type, no motion. Lists
/// turn page by page, and the screen gives one short "refresh" blink when the state changes,
/// the way e-paper does. iPad and Mac open like a book: status on the left page, nodes on
/// the right.
struct InkSkin: View {
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        Group {
            #if os(macOS)
                InkRegular()
            #else
                if sizeClass == .regular { InkRegular() } else { InkCompact() }
            #endif
        }
        .transaction { $0.animation = nil }  // e-paper does not animate
        .grayscale(1)  // no color at all, flags included
        .skinSheets(nodePicker: { group in AnyView(InkNodePicker(initialGroup: group)) })
    }
}

enum InkTab: Hashable, CaseIterable {
    case home, nodes, activity, settings

    var title: String {
        switch self {
        case .home: SkinL("Home")
        case .nodes: SkinL("Nodes")
        case .activity: SkinL("Activity")
        case .settings: SkinL("Settings")
        }
    }
}

// MARK: - Type and ornaments

enum InkType {
    static func serif(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    static func caps(_ size: CGFloat = 11) -> Font {
        .system(size: size, weight: .semibold, design: .serif).smallCaps()
    }
}

/// A dotted leader, as between a chapter title and its page number.
private struct InkLeader: View {
    @Environment(\.skinTheme) private var theme

    var body: some View {
        GeometryReader { proxy in
            Path { path in
                path.move(to: CGPoint(x: 0, y: proxy.size.height - 1))
                path.addLine(to: CGPoint(x: proxy.size.width, y: proxy.size.height - 1))
            }
            .stroke(theme.secondaryText, style: StrokeStyle(lineWidth: 1.2, lineCap: .round, dash: [0.1, 5]))
        }
        .frame(height: 6)
    }
}

/// `Title ........ value`, optionally tappable.
struct InkLeaderRow: View {
    @Environment(\.skinTheme) private var theme
    let title: String
    let value: String
    var action: (() -> Void)?

    var body: some View {
        let row = HStack(alignment: .lastTextBaseline, spacing: 6) {
            Text(title).font(InkType.serif(17)).foregroundStyle(theme.text)
            InkLeader().layoutPriority(-1)
            Text(value).font(InkType.serif(17, .semibold)).monospacedDigit().foregroundStyle(theme.text).lineLimit(1)
            if action != nil {
                Text(verbatim: "›").font(InkType.serif(17)).foregroundStyle(theme.secondaryText)
            }
        }
        .frame(minHeight: 34)
        .contentShape(Rectangle())
        if let action {
            Button(action: action) { row }.buttonStyle(InkPressStyle())
        } else {
            row
        }
    }
}

/// Buttons invert while pressed, like a highlighted word on e-paper.
struct InkPressStyle: ButtonStyle {
    @Environment(\.skinTheme) private var theme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? theme.text.opacity(0.12) : .clear)
    }
}

/// A boxed, full-width button. `filled` inverts it.
struct InkButton: View {
    @Environment(\.skinTheme) private var theme
    let title: String
    var filled = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(InkType.serif(19, .semibold))
                .foregroundStyle(filled ? theme.onAccent : theme.text)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(filled ? theme.text : theme.surface)
                .overlay(Rectangle().strokeBorder(theme.text, lineWidth: 2))
        }
        .buttonStyle(InkInvertStyle(filled: filled))
    }
}

/// Pressing prints the button in reverse.
private struct InkInvertStyle: ButtonStyle {
    var filled: Bool
    func makeBody(configuration: Configuration) -> some View {
        if configuration.isPressed {
            configuration.label.colorInvert()
        } else {
            configuration.label
        }
    }
}

/// Boxed segmented choice; the selected cell is inked in.
struct InkSegments<Value: Hashable>: View {
    @Environment(\.skinTheme) private var theme
    let options: [(value: Value, title: String)]
    let selection: Value
    let onSelect: (Value) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options.indices, id: \.self) { index in
                let option = options[index]
                let selected = option.value == selection
                Button {
                    onSelect(option.value)
                } label: {
                    Text(option.title)
                        .font(InkType.serif(15, selected ? .semibold : .regular))
                        .foregroundStyle(selected ? theme.onAccent : theme.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(selected ? theme.text : .clear)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
                if index < options.count - 1 {
                    Rectangle().fill(theme.text).frame(width: 1.5)
                }
            }
        }
        .frame(height: 40)
        .overlay(Rectangle().strokeBorder(theme.text, lineWidth: 1.5))
    }
}

/// Speed history as halftone columns: ink dots fill each column up to its value.
struct InkHalftoneChart: View {
    @Environment(\.skinTheme) private var theme
    let download: [Double]
    let upload: [Double]

    var body: some View {
        Canvas { context, size in
            let peak = max(download.max() ?? 1, upload.max() ?? 1, 1)
            let columns = max(download.count, 1)
            let cell: CGFloat = 4
            let columnWidth = size.width / CGFloat(columns)
            for (index, value) in download.enumerated() {
                let height = size.height * CGFloat(value / peak)
                let x = CGFloat(index) * columnWidth
                var y = size.height - cell
                var row = 0
                while y > size.height - height {
                    var dx: CGFloat = row % 2 == 0 ? 0 : cell / 2
                    while dx < columnWidth - 1 {
                        let dot = CGRect(x: x + dx, y: y, width: 1.8, height: 1.8)
                        context.fill(Path(ellipseIn: dot), with: .color(theme.text))
                        dx += cell
                    }
                    y -= cell
                    row += 1
                }
            }
            // Upload: a thin ink line on top.
            var line = Path()
            for (index, value) in upload.enumerated() {
                let point = CGPoint(x: (CGFloat(index) + 0.5) * columnWidth, y: size.height - size.height * CGFloat(value / peak))
                index == 0 ? line.move(to: point) : line.addLine(to: point)
            }
            context.stroke(line, with: .color(theme.secondaryText), style: StrokeStyle(lineWidth: 1.2, dash: [3, 2]))
            // Baseline.
            context.fill(Path(CGRect(x: 0, y: size.height - 0.75, width: size.width, height: 1.5)), with: .color(theme.text))
        }
        .accessibilityLabel(Text(skin: "Traffic chart"))
    }
}

/// Five-cell latency meter: ■■■□□.
struct InkLatencyMeter: View {
    @Environment(\.skinTheme) private var theme
    let grade: LatencyGrade

    var body: some View {
        let filled = switch grade {
        case .excellent: 5
        case .good: 4
        case .fair: 2
        case .poor: 1
        case .unreachable, .untested: 0
        }
        HStack(spacing: 2) {
            ForEach(0 ..< 5, id: \.self) { index in
                Rectangle()
                    .fill(index < filled ? theme.text : .clear)
                    .overlay(Rectangle().strokeBorder(theme.text, lineWidth: 1))
                    .frame(width: 6, height: 10)
            }
        }
        .accessibilityHidden(true)
    }
}

/// One full-screen blink when `trigger` changes: the e-paper refresh. Skipped with Reduce
/// Motion.
private struct InkRefresh<Trigger: Equatable>: ViewModifier {
    let trigger: Trigger
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var flashing = false

    func body(content: Content) -> some View {
        content
            .overlay {
                Color.black.opacity(flashing ? 0.88 : 0).allowsHitTesting(false).ignoresSafeArea()
            }
            .onChange(of: trigger) { _, _ in
                guard !reduceMotion else { return }
                flashing = true
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(90))
                    flashing = false
                }
            }
    }
}

extension View {
    func inkRefresh(on trigger: some Equatable) -> some View {
        modifier(InkRefresh(trigger: trigger))
    }
}

// MARK: - Chrome

/// Top line of the "device": profile on the left, connection time on the right.
struct InkStatusLine: View {
    @Environment(SkinStore.self) private var store
    @Environment(SkinRouter.self) private var router
    @Environment(\.skinTheme) private var theme
    @Environment(\.skinConfiguration) private var configuration

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Button {
                    router.sheet = .profiles
                } label: {
                    Text(store.activeProfile?.name ?? configuration.appName)
                        .font(InkType.caps(12))
                        .tracking(1)
                        .foregroundStyle(theme.text)
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
                .disabled(!store.hasProfiles)
                Spacer()
                if store.isRunning {
                    HStack(spacing: 5) {
                        Circle().fill(theme.text).frame(width: 7, height: 7)
                        ElapsedText(since: store.connectedSince).font(InkType.serif(12)).monospacedDigit()
                    }
                    .foregroundStyle(theme.text)
                } else {
                    HStack(spacing: 5) {
                        Circle().strokeBorder(theme.text, lineWidth: 1).frame(width: 7, height: 7)
                        Text(store.phase.label).font(InkType.serif(12))
                    }
                    .foregroundStyle(theme.secondaryText)
                }
            }
            Rectangle().fill(theme.text).frame(height: 1)
        }
    }
}

/// Bottom toolbar: words, the current one underlined.
private struct InkToolbar<Tab: Hashable>: View {
    @Environment(\.skinTheme) private var theme
    @Binding var selection: Tab
    let items: [(tab: Tab, title: String)]

    var body: some View {
        VStack(spacing: 0) {
            Rectangle().fill(theme.text).frame(height: 1)
            HStack(spacing: 0) {
                ForEach(items.indices, id: \.self) { index in
                    let item = items[index]
                    let selected = item.tab == selection
                    Button {
                        selection = item.tab
                    } label: {
                        VStack(spacing: 3) {
                            Text(item.title).font(InkType.serif(15, selected ? .bold : .regular))
                            Rectangle().fill(selected ? theme.text : .clear).frame(width: 22, height: 2)
                        }
                        .foregroundStyle(selected ? theme.text : theme.secondaryText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        }
        .background(theme.background)
    }
}

// MARK: - iPhone

private struct InkCompact: View {
    @Environment(SkinStore.self) private var store
    @Environment(SkinRouter.self) private var router
    @Environment(\.skinTheme) private var theme
    @State private var tab: InkTab = .home

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch tab {
                case .home: InkHomePage().padding(.horizontal, 22)
                case .nodes: InkNodesBook(showsHeader: true).padding(.horizontal, 22)
                case .activity: NavigationStack { InkActivity() }
                case .settings: NavigationStack { MorePage(title: SkinL("Settings")) }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            InkToolbar(selection: $tab, items: InkTab.allCases.map { ($0, $0.title) })
        }
        .background(theme.background)
        .inkRefresh(on: tab)
        .inkRefresh(on: store.phase)
        .onChange(of: router.homeRequests) { _, _ in tab = .home }
    }
}

/// The status page: a large state line, a table of contents of the connection, the chart,
/// the mode and one boxed button.
struct InkHomePage: View {
    @Environment(SkinStore.self) private var store
    @Environment(SkinRouter.self) private var router
    @Environment(SkinPreferences.self) private var preferences
    @Environment(\.skinTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            InkStatusLine().padding(.top, 8)
            if store.needsGate {
                Spacer()
                NoProfileView()
                Spacer()
            } else {
                Text(skin: "Status").font(InkType.caps(12)).tracking(1.5).foregroundStyle(theme.secondaryText).padding(.top, 22)
                Text(store.phase.label)
                    .font(InkType.serif(44, .bold))
                    .foregroundStyle(theme.text)
                    .padding(.top, 2)
                if store.isRunning, let node = store.currentNode {
                    Text(SkinL("through %@", node.tag))
                        .font(InkType.serif(19).italic())
                        .foregroundStyle(theme.text)
                        .lineLimit(1)
                } else {
                    Text(skin: "Turn it on and pick where you want to go.")
                        .font(InkType.serif(17).italic())
                        .foregroundStyle(theme.secondaryText)
                }

                VStack(spacing: 2) {
                    let node = store.currentNode
                    InkLeaderRow(title: SkinL("Node"), value: node?.tag ?? "—") {
                        router.showNodes(group: store.primaryGroup?.tag)
                    }
                    InkLeaderRow(title: SkinL("Round trip"), value: preferences.vocabulary.latency(node?.delay ?? 0))
                    if store.isRunning {
                        InkLeaderRow(title: SkinL("Download"), value: SkinFormat.rate(store.status.downlink))
                        InkLeaderRow(title: SkinL("Upload"), value: SkinFormat.rate(store.status.uplink))
                        InkLeaderRow(title: SkinL("Session traffic"), value: SkinFormat.bytes(store.status.totalTraffic))
                    }
                }
                .padding(.top, 20)

                if store.isRunning {
                    InkHalftoneChart(download: store.downlinkHistory, upload: store.uplinkHistory)
                        .frame(height: 110)
                        .padding(.top, 18)
                }

                Spacer(minLength: 16)

                if store.isRunning, store.clashModes.count > 1 {
                    InkSegments(
                        options: store.clashModes.map { ($0, preferences.vocabulary.modeShort($0)) },
                        selection: store.clashMode,
                        onSelect: store.setClashMode
                    )
                    .padding(.bottom, 12)
                }
                InkButton(title: store.phase.isActive ? SkinL("Disconnect") : SkinL("Connect"), filled: !store.phase.isActive) {
                    store.toggleService()
                }
                .disabled(store.phase == .unavailable || store.phase.isTransitioning)
                .padding(.bottom, 12)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Nodes, page by page

/// Nodes of one group, a page at a time. Tap a row to use it; flip with the arrows or a swipe.
struct InkNodesBook: View {
    @Environment(SkinStore.self) private var store
    @Environment(SkinRouter.self) private var router
    @Environment(SkinPreferences.self) private var preferences
    @Environment(\.skinTheme) private var theme
    var initialGroup: String?
    var showsHeader = false
    var onSelect: (() -> Void)?
    @State private var groupTag: String?
    @State private var page = 0

    private let rowHeight: CGFloat = 50

    var body: some View {
        let selectable = store.groups.filter(\.selectable)
        let group = store.group(groupTag ?? initialGroup ?? router.focusedGroup ?? "") ?? store.primaryGroup
        VStack(alignment: .leading, spacing: 0) {
            if showsHeader { InkStatusLine().padding(.top, 8) }
            HStack(alignment: .firstTextBaseline) {
                Text(skin: "Nodes").font(InkType.serif(30, .bold)).foregroundStyle(theme.text)
                Spacer()
                if let group {
                    Button {
                        store.urlTest(group.tag)
                    } label: {
                        Text(store.testingGroups.contains(group.tag) ? SkinL("Testing…") : SkinL("Test latency"))
                            .font(InkType.serif(15).italic())
                            .underline()
                            .foregroundStyle(theme.text)
                    }
                    .buttonStyle(.plain)
                    .disabled(store.testingGroups.contains(group.tag))
                }
            }
            .padding(.top, showsHeader ? 18 : 0)

            if selectable.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 18) {
                        ForEach(selectable) { item in
                            let selected = item.tag == group?.tag
                            Button {
                                groupTag = item.tag
                                page = 0
                            } label: {
                                Text(item.tag)
                                    .font(InkType.serif(15, selected ? .bold : .regular))
                                    .underline(selected)
                                    .foregroundStyle(selected ? theme.text : theme.secondaryText)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            Rectangle().fill(theme.text).frame(height: 1).padding(.top, 6)

            if let group {
                GeometryReader { proxy in
                    let perPage = max(Int((proxy.size.height - 56) / rowHeight), 1)
                    let pages = max((group.items.count + perPage - 1) / perPage, 1)
                    let current = min(page, pages - 1)
                    let items = Array(group.items.dropFirst(current * perPage).prefix(perPage))
                    VStack(spacing: 0) {
                        ForEach(items) { item in
                            row(item, in: group)
                        }
                        Spacer(minLength: 0)
                        pager(current: current, pages: pages)
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 30).onEnded { value in
                            if value.translation.width < -40 { page = min(current + 1, pages - 1) }
                            if value.translation.width > 40 { page = max(current - 1, 0) }
                        }
                    )
                }
                .inkRefresh(on: page)
                .inkRefresh(on: group.tag)
            } else {
                Spacer()
                Text(store.isRunning ? SkinL("This profile has no selectable groups.") : SkinL("Start the service to see groups."))
                    .font(InkType.serif(17).italic())
                    .foregroundStyle(theme.secondaryText)
                    .frame(maxWidth: .infinity)
                Spacer()
            }
        }
    }

    private func row(_ item: SkinOutbound, in group: SkinOutboundGroup) -> some View {
        let selected = item.tag == group.selected
        return Button {
            store.select(item.tag, in: group.tag)
            onSelect?()
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.tag).font(InkType.serif(17, selected ? .bold : .regular)).lineLimit(1)
                    Text(item.type).font(InkType.caps(11)).tracking(0.8).opacity(0.7)
                }
                Spacer()
                Text(preferences.vocabulary.latency(item.delay)).font(InkType.serif(14)).monospacedDigit()
                InkLatencyMeter(grade: item.grade)
            }
            .foregroundStyle(selected ? theme.onAccent : theme.text)
            .padding(.horizontal, 10)
            .frame(height: rowHeight)
            .background(selected ? theme.text : .clear)
            .overlay(alignment: .bottom) { Rectangle().fill(theme.separator).frame(height: 0.5) }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .environment(\.skinTheme, selected ? invertedTheme : theme)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityValue(Text(item.grade.word))
    }

    /// Selected rows are printed in reverse.
    private var invertedTheme: SkinTheme {
        var inverted = theme
        inverted.text = theme.onAccent
        return inverted
    }

    private func pager(current: Int, pages: Int) -> some View {
        HStack {
            Button {
                page = max(current - 1, 0)
            } label: {
                Text(skin: "‹ Previous").font(InkType.serif(15))
            }
            .disabled(current == 0)
            Spacer()
            Text(SkinL("Page %lld of %lld", current + 1, pages)).font(InkType.serif(14).italic()).monospacedDigit()
            Spacer()
            Button {
                page = min(current + 1, pages - 1)
            } label: {
                Text(skin: "Next ›").font(InkType.serif(15))
            }
            .disabled(current >= pages - 1)
        }
        .buttonStyle(.plain)
        .foregroundStyle(theme.text)
        .frame(height: 48)
    }
}

/// The nodes sheet opened from Home and the command palette.
private struct InkNodePicker: View {
    @Environment(\.skinTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    var initialGroup: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button(SkinL("Done")) { dismiss() }
                    .font(InkType.serif(17, .semibold))
                    .foregroundStyle(theme.text)
            }
            .padding(.top, 16)
            InkNodesBook(initialGroup: initialGroup, onSelect: { dismiss() })
        }
        .padding(.horizontal, 22)
        .background(theme.background)
        .transaction { $0.animation = nil }
        .grayscale(1)
    }
}

// MARK: - Activity

private struct InkActivity: View {
    @Environment(\.skinTheme) private var theme
    @State private var section = 0

    var body: some View {
        VStack(spacing: 0) {
            InkSegments(
                options: [(0, SkinL("Connections")), (1, SkinL("Logs"))],
                selection: section,
                onSelect: { section = $0 }
            )
            .padding(.horizontal, 22)
            .padding(.vertical, 10)
            if section == 0 { ConnectionsPage() } else { LogsPage() }
        }
        .background(theme.background)
        .navigationTitle(SkinL("Activity"))
        .navigationBarTitleDisplayModeInline()
        .inkRefresh(on: section)
    }
}

// MARK: - iPad / Mac: an open book

private struct InkRegular: View {
    @Environment(SkinStore.self) private var store
    @Environment(SkinRouter.self) private var router
    @Environment(\.skinTheme) private var theme
    @State private var tab: InkTab = .home

    private var tabs: [InkTab] { [.home, .activity, .settings] }

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch tab {
                case .home, .nodes:
                    HStack(spacing: 0) {
                        InkHomePage()
                            .padding(.horizontal, 36)
                            .frame(maxWidth: 480)
                            .frame(maxWidth: .infinity)
                        // The gutter between the two pages.
                        HStack(spacing: 3) {
                            Rectangle().fill(theme.text.opacity(0.25)).frame(width: 1)
                            Rectangle().fill(theme.text.opacity(0.12)).frame(width: 1)
                        }
                        .padding(.vertical, 24)
                        InkNodesBook(showsHeader: false)
                            .padding(.top, 44)
                            .padding(.horizontal, 36)
                            .frame(maxWidth: 520)
                            .frame(maxWidth: .infinity)
                    }
                case .activity: NavigationStack { InkActivity() }
                case .settings: NavigationStack { MorePage(title: SkinL("Settings")) }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            InkToolbar(selection: $tab, items: tabs.map { ($0, $0 == .home ? SkinL("Reading") : $0.title) })
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
                .background(theme.background)
        }
        .background(theme.background)
        .inkRefresh(on: tab)
        .inkRefresh(on: store.phase)
        .onChange(of: router.homeRequests) { _, _ in tab = .home }
    }
}
