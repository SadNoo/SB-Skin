import SkywaveShared
import SwiftUI

/// K · Corner Store. Nodes are goods on the shelves and latency is the price on the tag (the
/// lower, the better). Connecting opens the store, the mode is how you get your goods, the
/// profile is a membership card and connections print as a receipt. Every playful label keeps
/// the plain one next to it, so nothing is ambiguous.
struct MartSkin: View {
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        Group {
            #if os(macOS)
                MartRegular()
            #else
                if sizeClass == .regular { MartRegular() } else { MartCompact() }
            #endif
        }
        .skinSheets(nodePicker: { group in AnyView(MartAislesSheet(initialGroup: group)) })
    }
}

enum MartTab: Hashable, CaseIterable {
    case store, aisles, receipt, service

    var title: String {
        switch self {
        case .store: SkinL("Store")
        case .aisles: SkinL("Aisles")
        case .receipt: SkinL("Receipt")
        case .service: SkinL("Service Desk")
        }
    }

    var symbol: String {
        switch self {
        case .store: "storefront"
        case .aisles: "basket"
        case .receipt: "scroll"
        case .service: "bell"
        }
    }
}

// MARK: - Store furniture

enum MartPalette {
    static let tag = Color(hex: 0xFFD84D)
    static let tagInk = Color(hex: 0x231C16)
    static let open = Color(light: Color(hex: 0x0E8A6A), dark: Color(hex: 0x3ED6A7))
    static let boxes: [Color] = [
        Color(hex: 0xFFB4A2), Color(hex: 0xA8DADC), Color(hex: 0xFFD6A5),
        Color(hex: 0xCDB4DB), Color(hex: 0xB9E4C9), Color(hex: 0xBDE0FE),
    ]

    /// A stable pastel for a product box.
    static func box(for tag: String) -> Color {
        let hash = tag.unicodeScalars.reduce(UInt32(5381)) { ($0 &* 33) &+ $1.value }
        return boxes[Int(hash % UInt32(boxes.count))]
    }
}

/// Striped shop awning with a scalloped edge. `extra` grows it up under the status bar.
struct MartAwning: View {
    @Environment(\.skinTheme) private var theme
    var stripes = 9
    var extra: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width / CGFloat(stripes)
            let body = proxy.size.height - width / 2
            ZStack(alignment: .topLeading) {
                HStack(spacing: 0) {
                    ForEach(0 ..< stripes, id: \.self) { index in
                        VStack(spacing: 0) {
                            Rectangle().frame(height: body)
                            Circle().frame(width: width, height: width).offset(y: -width / 2)
                        }
                        .foregroundStyle(index.isMultiple(of: 2) ? theme.accent : Color.white)
                        .frame(width: width)
                    }
                }
            }
        }
        .frame(height: 44 + extra)
        .clipped()
        .accessibilityHidden(true)
    }
}

/// The lit sign by the door.
struct MartOpenSign: View {
    @Environment(SkinStore.self) private var store
    @Environment(\.skinTheme) private var theme

    var body: some View {
        let open = store.isRunning
        let title: String = open ? SkinL("OPEN") : (store.phase.isTransitioning ? "···" : SkinL("CLOSED"))
        Text(title)
            .font(.system(size: 13, weight: .heavy, design: .rounded))
            .tracking(1.5)
            .foregroundStyle(open ? MartPalette.open : theme.secondaryText)
            .padding(.horizontal, 10)
            .frame(height: 26)
            .overlay(Capsule().strokeBorder(open ? MartPalette.open : theme.secondaryText.opacity(0.5), lineWidth: 2))
            .shadow(color: open ? MartPalette.open.opacity(0.55) : .clear, radius: 6)
            .accessibilityLabel(Text(store.phase.label))
    }
}

/// Yellow price tag with a punched hole. The price is the latency.
struct MartPriceTag: View {
    @Environment(SkinPreferences.self) private var preferences
    let delay: UInt16
    var large = false

    var body: some View {
        let grade = LatencyGrade(delay: delay)
        HStack(spacing: large ? 8 : 5) {
            Circle().fill(Color.white.opacity(0.9)).frame(width: large ? 9 : 6, height: large ? 9 : 6)
            switch grade {
            case .unreachable:
                Text(skin: "Sold out").font(.system(size: large ? 16 : 12, weight: .heavy, design: .rounded))
            case .untested:
                Text(skin: "No price yet").font(.system(size: large ? 14 : 11, weight: .bold, design: .rounded))
            default:
                if preferences.vocabulary == .everyday {
                    Text(grade.word).font(.system(size: large ? 14 : 12, weight: .heavy, design: .rounded)).lineLimit(1).fixedSize()
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 1) {
                        Text(verbatim: "\(delay)").font(.system(size: large ? 26 : 16, weight: .black, design: .rounded)).monospacedDigit()
                        Text(verbatim: "ms").font(.system(size: large ? 12 : 9, weight: .bold, design: .rounded))
                    }
                }
            }
        }
        .foregroundStyle(grade == .unreachable ? Color(hex: 0xB42318) : MartPalette.tagInk)
        .padding(.leading, large ? 10 : 7)
        .padding(.trailing, large ? 14 : 9)
        .frame(height: large ? 44 : 28)
        .background(MartPalette.tag, in: TagShape())
        .rotationEffect(.degrees(large ? -4 : 0))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(preferences.vocabulary.latency(delay)))
    }
}

/// A price tag outline: a rectangle with a clipped left point.
private struct TagShape: Shape {
    func path(in rect: CGRect) -> Path {
        let notch = rect.height * 0.32
        var path = Path()
        path.move(to: CGPoint(x: notch, y: 0))
        path.addLine(to: CGPoint(x: rect.maxX - 4, y: 0))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: 4), control: CGPoint(x: rect.maxX, y: 0))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - 4))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - 4, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: notch, y: rect.maxY))
        path.addLine(to: CGPoint(x: 0, y: rect.midY))
        path.closeSubpath()
        return path
    }
}

/// A product box with the node's region printed on it.
struct MartProductBox: View {
    let tag: String
    var size: CGFloat = 52

    var body: some View {
        let code = SkinRegion.infer(from: tag)?.code ?? String(SkinRegion.stripFlag(tag).prefix(2)).uppercased()
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: size * 0.18, style: .continuous).fill(MartPalette.box(for: tag))
            Rectangle().fill(Color.black.opacity(0.08)).frame(height: size * 0.22)
            Text(verbatim: code)
                .font(.system(size: size * 0.34, weight: .black, design: .rounded))
                .foregroundStyle(MartPalette.tagInk.opacity(0.85))
                .frame(maxHeight: .infinity)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Bars that look like a barcode, stable for a given string.
private struct Barcode: View {
    let seed: String

    var body: some View {
        Canvas { context, size in
            var hash = seed.unicodeScalars.reduce(UInt64(1469598103934665603)) { ($0 ^ UInt64($1.value)) &* 1099511628211 }
            var x: CGFloat = 0
            while x < size.width {
                hash = hash &* 6364136223846793005 &+ 1442695040888963407
                let width = CGFloat(1 + (hash >> 60) % 3)
                if (hash >> 33) % 3 != 0 {
                    context.fill(Path(CGRect(x: x, y: 0, width: width, height: size.height)), with: .color(.black))
                }
                x += width + 1
            }
        }
        .accessibilityHidden(true)
    }
}

/// How you get your goods = the mode. Playful name on the chip, the real mode underneath.
struct MartDeliveryPicker: View {
    @Environment(SkinStore.self) private var store
    @Environment(SkinPreferences.self) private var preferences
    @Environment(\.skinTheme) private var theme

    static func title(_ mode: String) -> String {
        switch mode.lowercased() {
        case "rule": SkinL("Staff picks")
        case "global": SkinL("Deliver all")
        case "direct": SkinL("Self pickup")
        default: mode
        }
    }

    var body: some View {
        if store.clashModes.count > 1 {
            VStack(alignment: .leading, spacing: 8) {
                Text(skin: "How to get it").font(.system(.caption, design: .rounded).weight(.bold)).foregroundStyle(theme.secondaryText)
                HStack(spacing: 8) {
                    ForEach(store.clashModes, id: \.self) { mode in
                        let selected = mode == store.clashMode
                        Button {
                            store.setClashMode(mode)
                        } label: {
                            VStack(spacing: 1) {
                                Text(Self.title(mode)).font(.system(.subheadline, design: .rounded).weight(.bold)).lineLimit(1).minimumScaleFactor(0.8)
                                Text(preferences.vocabulary.mode(mode)).font(.system(size: 10, design: .rounded)).lineLimit(1).minimumScaleFactor(0.7).opacity(0.75)
                            }
                            .foregroundStyle(selected ? theme.onAccent : theme.text)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(selected ? theme.accent : theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(selected ? .clear : theme.separator, lineWidth: 1))
                        }
                        .buttonStyle(SkinPressStyle())
                        .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }
            }
        }
    }
}

// MARK: - Store front

/// Sign, today's pick, the door button, delivery, membership card and a few counters.
struct MartStoreFront: View {
    @Environment(SkinStore.self) private var store
    @Environment(SkinRouter.self) private var router
    @Environment(\.skinTheme) private var theme
    @Environment(\.skinConfiguration) private var configuration

    var body: some View {
        GeometryReader { proxy in
            storeScroll(topInset: proxy.safeAreaInsets.top)
        }
    }

    private func storeScroll(topInset: CGFloat) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                MartAwning(extra: topInset)
                VStack(spacing: 16) {
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(configuration.appName).font(.system(size: 30, weight: .black, design: .rounded)).foregroundStyle(theme.text)
                            Text(skin: "Open 24 hours").font(.system(.caption, design: .rounded).weight(.bold)).foregroundStyle(theme.secondaryText)
                        }
                        Spacer()
                        MartOpenSign()
                    }
                    if store.needsGate {
                        NoProfileView()
                    } else {
                        todaysPick
                        doorButton
                        if store.isRunning {
                            MartDeliveryPicker()
                        }
                        memberCard
                        if store.isRunning { counters }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .padding(.bottom, 24)
            }
        }
        .scrollIndicators(.hidden)
        .background(theme.background)
        .ignoresSafeArea(edges: .top)
    }

    private var todaysPick: some View {
        let node = store.currentNode
        let group = store.primaryGroup
        return Button {
            router.showNodes(group: group?.tag)
        } label: {
            HStack(spacing: 14) {
                MartProductBox(tag: node?.tag ?? "?", size: 56)
                VStack(alignment: .leading, spacing: 3) {
                    Text(skin: "Today's pick").font(.system(.caption, design: .rounded).weight(.heavy)).foregroundStyle(theme.accent)
                    Text(node?.tag ?? SkinL("Nothing yet")).font(.system(.title3, design: .rounded).weight(.heavy)).foregroundStyle(theme.text).lineLimit(1).minimumScaleFactor(0.6)
                    if let node {
                        Text(SkinL("Shelf %@ · %@", group?.tag ?? "—", node.type)).font(.system(.caption, design: .rounded)).foregroundStyle(theme.secondaryText).lineLimit(1)
                    }
                }
                .layoutPriority(1)
                Spacer(minLength: 4)
                if let node { MartPriceTag(delay: node.delay, large: true).fixedSize() }
            }
            .padding(16)
            .background(theme.surface, in: RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous).strokeBorder(theme.separator, lineWidth: 1))
        }
        .buttonStyle(SkinPressStyle())
        .disabled(group == nil)
    }

    private var doorButton: some View {
        let active = store.phase.isActive
        return Button {
            store.toggleService()
        } label: {
            HStack(spacing: 10) {
                if store.phase.isTransitioning {
                    ProgressView().tint(active ? theme.accent : .white)
                } else {
                    Image(systemName: active ? "door.left.hand.closed" : "door.left.hand.open").font(.title3.weight(.bold))
                }
                VStack(alignment: .leading, spacing: 0) {
                    Text(active ? SkinL("Close the store") : SkinL("Open the store")).font(.system(.headline, design: .rounded).weight(.heavy))
                    Text(active ? SkinL("Disconnect") : SkinL("Connect")).font(.system(.caption, design: .rounded).weight(.semibold)).opacity(0.8)
                }
                Spacer()
                if store.isRunning {
                    ElapsedText(since: store.connectedSince).font(.system(.subheadline, design: .rounded).weight(.bold)).monospacedDigit()
                }
            }
            .foregroundStyle(active ? theme.accent : .white)
            .padding(.horizontal, 18)
            .frame(height: 62)
            .background(active ? theme.accent.opacity(0.12) : theme.accent, in: RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous))
        }
        .buttonStyle(SkinPressStyle())
        .disabled(store.phase == .unavailable || store.phase.isTransitioning)
        .sensoryFeedback(.impact(weight: .medium), trigger: store.phase.isActive)
    }

    private var memberCard: some View {
        Button {
            router.sheet = .profiles
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(skin: "MEMBER").font(.system(size: 12, weight: .black, design: .rounded)).tracking(2)
                    Spacer()
                    Image(systemName: "star.fill").font(.caption)
                }
                .foregroundStyle(Color.white.opacity(0.9))
                Text(store.activeProfile?.name ?? SkinL("No Profile")).font(.system(.title3, design: .rounded).weight(.heavy)).foregroundStyle(.white).lineLimit(1)
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(skin: "Points this session").font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundStyle(Color.white.opacity(0.8))
                        Text(verbatim: SkinFormat.bytes(store.status.totalTraffic)).font(.system(.title2, design: .rounded).weight(.black)).monospacedDigit().foregroundStyle(.white)
                    }
                    Spacer()
                    Barcode(seed: store.activeProfile?.name ?? "skywave")
                        .frame(width: 96, height: 30)
                        .padding(5)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 4))
                }
            }
            .padding(16)
            .background(Color(hex: 0x1F4E5F), in: RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous))
        }
        .buttonStyle(SkinPressStyle())
        .disabled(!store.hasProfiles)
        .accessibilityHint(Text(skin: "Switch profile"))
    }

    private var counters: some View {
        HStack(spacing: 10) {
            counter(SkinL("Customers"), "\(store.status.totalConnections)", "person.2.fill")
            counter(SkinL("Checkout speed"), SkinFormat.rate(store.status.downlink), "cart.fill")
        }
    }

    private func counter(_ title: String, _ value: String, _ symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: symbol).font(.system(.caption, design: .rounded).weight(.bold)).foregroundStyle(theme.secondaryText)
            Text(verbatim: value).font(.system(.title3, design: .rounded).weight(.heavy)).monospacedDigit().foregroundStyle(theme.text).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(theme.elevatedSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Aisles

/// Every selectable group is an aisle; its nodes are the goods on the shelf.
struct MartAisles: View {
    @Environment(SkinStore.self) private var store
    @Environment(\.skinTheme) private var theme
    @Environment(\.horizontalSizeClass) private var sizeClass
    var onPick: (() -> Void)?
    var focusedGroup: String?

    var body: some View {
        let aisles = store.groups.filter(\.selectable)
        ScrollViewReader { reader in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 22) {
                    if aisles.isEmpty {
                        ContentUnavailableView(
                            SkinL("Shelves are empty"),
                            systemImage: "basket",
                            description: Text(store.isRunning ? SkinL("This profile has no selectable groups.") : SkinL("Start the service to see groups."))
                        )
                        .padding(.top, 60)
                    }
                    ForEach(Array(aisles.enumerated()), id: \.element.id) { index, group in
                        aisle(group, number: index + 1).id(group.tag)
                    }
                }
                .padding(16)
            }
            .onAppear {
                if let focusedGroup { reader.scrollTo(focusedGroup, anchor: .top) }
            }
        }
        .background(theme.background)
    }

    private func aisle(_ group: SkinOutboundGroup, number: Int) -> some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: sizeClass == .regular ? 3 : 2)
        let testing = store.testingGroups.contains(group.tag)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: "A\(number)")
                    .font(.system(.caption, design: .rounded).weight(.black))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .frame(height: 20)
                    .background(theme.accent, in: RoundedRectangle(cornerRadius: 5))
                Text(group.tag).font(.system(.title3, design: .rounded).weight(.heavy)).foregroundStyle(theme.text).lineLimit(1)
                Spacer()
                Button {
                    store.urlTest(group.tag)
                } label: {
                    Label(testing ? SkinL("Checking prices…") : SkinL("Check prices"), systemImage: "barcode.viewfinder")
                        .font(.system(.footnote, design: .rounded).weight(.bold))
                        .foregroundStyle(theme.accent)
                }
                .buttonStyle(.plain)
                .disabled(testing)
            }
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(group.items) { item in
                    product(item, in: group)
                }
            }
            // The shelf board.
            RoundedRectangle(cornerRadius: 3).fill(theme.text.opacity(0.12)).frame(height: 6)
        }
    }

    private func product(_ item: SkinOutbound, in group: SkinOutboundGroup) -> some View {
        let selected = item.tag == group.selected
        let soldOut = item.grade == .unreachable
        return Button {
            store.select(item.tag, in: group.tag)
            onPick?()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    MartProductBox(tag: item.tag, size: 40)
                    Spacer()
                    if selected {
                        Image(systemName: "checkmark.circle.fill").font(.title3).foregroundStyle(MartPalette.open)
                    }
                }
                Text(item.tag).font(.system(.subheadline, design: .rounded).weight(.bold)).foregroundStyle(theme.text).lineLimit(1)
                Text(item.type).font(.system(.caption2, design: .rounded)).foregroundStyle(theme.secondaryText)
                MartPriceTag(delay: item.delay)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(selected ? MartPalette.open : theme.separator, lineWidth: selected ? 2.5 : 1))
            .overlay {
                if soldOut {
                    Text(skin: "Sold out")
                        .font(.system(.headline, design: .rounded).weight(.black))
                        .foregroundStyle(Color(hex: 0xB42318))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color(hex: 0xB42318), lineWidth: 2.5))
                        .rotationEffect(.degrees(-14))
                        .opacity(0.85)
                }
            }
            .opacity(soldOut && !selected ? 0.7 : 1)
        }
        .buttonStyle(SkinPressStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct MartAislesSheet: View {
    @Environment(\.skinTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    var initialGroup: String?

    var body: some View {
        NavigationStack {
            MartAisles(onPick: { dismiss() }, focusedGroup: initialGroup)
                .navigationTitle(SkinL("Aisles"))
                .navigationBarTitleDisplayModeInline()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(SkinL("Done")) { dismiss() }
                    }
                }
        }
    }
}

// MARK: - Receipt

/// Live connections printed as receipt lines: item, how it went, bytes.
struct MartReceipt: View {
    @Environment(SkinStore.self) private var store
    @Environment(SkinRouter.self) private var router
    @Environment(\.skinTheme) private var theme
    @State private var confirmCloseAll = false

    var body: some View {
        let rows = store.activeConnections.sorted { $0.totalBytes > $1.totalBytes }
        ScrollView {
            VStack(spacing: 0) {
                VStack(spacing: 4) {
                    Text(skin: "*** RECEIPT ***").font(.system(.headline, design: .monospaced).weight(.bold))
                    Text(Date.now, format: .dateTime.year().month().day().hour().minute())
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Color(hex: 0x6B6258))
                }
                .padding(.vertical, 14)
                dashed
                if !store.connectionsLoaded {
                    ProgressView().padding(30)
                } else if rows.isEmpty {
                    Text(store.isRunning ? SkinL("No connections") : SkinL("Start the service to see live connections."))
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(Color(hex: 0x6B6258))
                        .padding(30)
                }
                ForEach(rows) { connection in
                    NavigationLink(value: connection.id) {
                        line(connection)
                    }
                    .buttonStyle(.plain)
                }
                dashed
                HStack {
                    Text(skin: "TOTAL")
                    Spacer()
                    Text(verbatim: SkinFormat.bytes(rows.reduce(0) { $0 + $1.totalBytes }))
                }
                .font(.system(.body, design: .monospaced).weight(.bold))
                .padding(.vertical, 12)
                Barcode(seed: "\(rows.count)").frame(height: 34).padding(.horizontal, 30).padding(.bottom, 8)
                Text(skin: "Thank you for shopping").font(.system(.caption, design: .monospaced)).foregroundStyle(Color(hex: 0x6B6258)).padding(.bottom, 16)
            }
            .foregroundStyle(Color(hex: 0x231C16))
            .padding(.horizontal, 16)
            .background(Color(hex: 0xFFFDF8))
            .overlay(alignment: .bottom) { ZigZag().fill(theme.background).frame(height: 8) }
            .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
            .padding(16)
        }
        .background(theme.background)
        .navigationTitle(SkinL("Receipt"))
        .navigationBarTitleDisplayModeInline()
        .navigationDestination(for: String.self) { id in ConnectionDetailPage(connectionID: id) }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(SkinL("Store announcements (logs)"), systemImage: "megaphone") { router.sheet = .logs }
                    Button(SkinL("Close All Connections"), systemImage: "xmark.circle", role: .destructive) { confirmCloseAll = true }
                        .disabled(rows.isEmpty)
                } label: {
                    Label(SkinL("Options"), systemImage: "ellipsis.circle")
                }
            }
        }
        .confirmationDialog(SkinL("Close all connections?"), isPresented: $confirmCloseAll, titleVisibility: .visible) {
            Button(SkinL("Close All"), role: .destructive) { store.closeAllConnections() }
        }
        .subscribesToConnections(store)
    }

    private var dashed: some View {
        Line().stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 3])).foregroundStyle(Color(hex: 0x231C16).opacity(0.5)).frame(height: 1)
    }

    private func line(_ connection: SkinConnection) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                Text(connection.hostName).font(.system(.subheadline, design: .monospaced).weight(.semibold)).lineLimit(1)
                Spacer(minLength: 8)
                Text(verbatim: SkinFormat.bytes(connection.totalBytes)).font(.system(.subheadline, design: .monospaced)).monospacedDigit()
            }
            Text(connection.isDirect ? SkinL("  self pickup (direct)") : SkinL("  delivered by %@", connection.outbound))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Color(hex: 0x6B6258))
                .lineLimit(1)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

private struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}

/// The torn bottom edge of a receipt.
private struct ZigZag: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let step: CGFloat = 10
        path.move(to: CGPoint(x: 0, y: rect.maxY))
        var x: CGFloat = 0
        while x < rect.maxX {
            path.addLine(to: CGPoint(x: x + step / 2, y: 0))
            path.addLine(to: CGPoint(x: x + step, y: rect.maxY))
            x += step
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - iPhone

private struct MartCompact: View {
    @Environment(SkinRouter.self) private var router
    @Environment(\.skinConfiguration) private var configuration
    @State private var tab: MartTab = .store

    var body: some View {
        SkinTabContainer(selection: $tab, tabs: MartTab.allCases, barHeight: 84) { tab in
            NavigationStack {
                switch tab {
                case .store: MartStoreFront().toolbar(.hidden)
                case .aisles: MartAisles().navigationTitle(SkinL("Aisles"))
                case .receipt: MartReceipt()
                case .service: MorePage(title: SkinL("Service Desk"))
                }
            }
        } bar: {
            FloatingTabBar(
                selection: $tab,
                items: MartTab.allCases.map { ($0, $0.title, $0.symbol) },
                badge: { $0 == .service ? configuration.hostPages.toolsBadge() : 0 }
            )
        }
        .onChange(of: router.homeRequests) { _, _ in tab = .store }
    }
}

// MARK: - iPad / Mac

private struct MartRegular: View {
    @Environment(SkinRouter.self) private var router
    @Environment(\.skinTheme) private var theme
    @State private var section = 0

    var body: some View {
        HStack(spacing: 0) {
            MartStoreFront()
                .frame(width: 400)
            Divider().overlay(theme.separator)
            NavigationStack {
                VStack(spacing: 0) {
                    Picker(SkinL("Section"), selection: $section) {
                        Text(skin: "Aisles").tag(0)
                        Text(skin: "Receipt").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(maxWidth: 320)
                    .padding(.vertical, 10)
                    if section == 0 { MartAisles() } else { MartReceipt() }
                }
                .background(theme.background)
                .navigationTitle(section == 0 ? SkinL("Aisles") : SkinL("Receipt"))
                .navigationBarTitleDisplayModeInline()
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            router.sheet = .more
                        } label: {
                            Label(SkinL("Service Desk"), systemImage: "bell")
                        }
                    }
                }
            }
        }
        .background(theme.background)
    }
}
