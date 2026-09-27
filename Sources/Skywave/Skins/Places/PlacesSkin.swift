import SkywaveShared
import SwiftUI

/// D · Places. Nodes are destinations on a map; latency reads like road conditions.
struct PlacesSkin: View {
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        Group {
            #if os(macOS)
                PlacesRegular()
            #else
                if sizeClass == .regular { PlacesRegular() } else { PlacesCompact() }
            #endif
        }
        .skinSheets(nodePicker: { group in AnyView(PlacesPicker(initialGroup: group)) })
    }
}

// MARK: - Helpers

extension SkinStore {
    /// Map pins for every node in a group that has a recognizable region.
    func placePins(in group: SkinOutboundGroup?, selectedTag: String?) -> [DotWorldMap.Pin] {
        guard let group else { return [] }
        var seen: Set<String> = []
        var pins: [DotWorldMap.Pin] = []
        let selectedRegion = selectedTag.flatMap(SkinRegion.infer(from:))
        for item in group.items where self.group(item.tag) == nil {
            guard let region = SkinRegion.infer(from: item.tag), !seen.contains(region.code) else { continue }
            seen.insert(region.code)
            pins.append(DotWorldMap.Pin(
                id: region.code,
                latitude: region.latitude,
                longitude: region.longitude,
                label: region.name,
                selected: region.code == selectedRegion?.code
            ))
        }
        return pins
    }
}

/// Region name when the node's place is known, the node tag otherwise.
func placeName(for tag: String?) -> String {
    guard let tag else { return "—" }
    return SkinRegion.infer(from: tag)?.name ?? SkinRegion.stripFlag(tag)
}

// MARK: - iPhone

private struct PlacesCompact: View {
    @Environment(SkinStore.self) private var store
    @Environment(SkinRouter.self) private var router
    @Environment(\.skinTheme) private var theme

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                ZStack(alignment: .top) {
                    theme.background.ignoresSafeArea()
                    PlacesMap(span: 80)
                        .frame(height: proxy.size.height * 0.62 + proxy.safeAreaInsets.top)
                        .ignoresSafeArea(edges: .top)
                        .opacity(store.isRunning ? 1 : 0.55)
                    VStack {
                        HStack {
                            PlacesProfileButton()
                            Spacer()
                            PlacesPowerSwitch()
                        }
                        .padding(.horizontal, 16)
                        Spacer()
                        PlacesCard()
                            .padding(.horizontal, 10)
                            .padding(.bottom, 4)
                    }
                }
            }
            .toolbar(.hidden)
        }
    }
}

/// The map centered on the current place.
private struct PlacesMap: View {
    @Environment(SkinStore.self) private var store
    @Environment(\.skinTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    var span: Double
    var centerOverride: (Double, Double)?

    var body: some View {
        let group = store.primaryGroup
        let node = store.currentNode
        let region = node.flatMap { SkinRegion.infer(from: $0.tag) }
        let center = centerOverride ?? (region.map { ($0.latitude - 6, $0.longitude) } ?? (30, 105))
        DotWorldMap(
            center: center,
            span: span,
            pins: store.placePins(in: group, selectedTag: node?.tag),
            dotColor: colorScheme == .dark ? Color(hex: 0x3A4B5C) : Color(hex: 0xAEBFCE),
            pinColor: theme.text,
            highlightColor: theme.accent,
            labelColor: theme.secondaryText,
            labelBackground: theme.text
        )
        .animation(.smooth(duration: 0.6), value: node?.tag)
    }
}

private struct PlacesProfileButton: View {
    @Environment(SkinStore.self) private var store
    @Environment(SkinRouter.self) private var router
    @Environment(\.skinTheme) private var theme

    var body: some View {
        HStack(spacing: 8) {
            Button {
                router.sheet = .more
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(theme.text)
                    .frame(width: 44, height: 44)
                    .glassEffect(.regular.interactive(), in: Circle())
            }
            .accessibilityLabel(Text(skin: "More"))
            Button {
                router.sheet = .profiles
            } label: {
                Text(store.activeProfile?.name ?? SkinL("No Profile"))
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(theme.text)
                    .lineLimit(1)
                    .padding(.horizontal, 14)
                    .frame(height: 44)
                    .glassEffect(.regular.interactive(), in: Capsule())
            }
            .disabled(!store.hasProfiles)
        }
        .buttonStyle(.plain)
    }
}

private struct PlacesPowerSwitch: View {
    @Environment(SkinStore.self) private var store
    @Environment(\.skinTheme) private var theme

    var body: some View {
        HStack(spacing: 10) {
            Text(store.phase.isActive ? SkinL("On") : SkinL("Off"))
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(theme.text)
            if store.phase.isTransitioning {
                ProgressView().frame(width: 51)
            } else {
                Toggle(SkinL("Connection"), isOn: Binding(get: { store.phase.isActive }, set: { _ in store.toggleService() }))
                    .labelsHidden()
                    .tint(theme.accent)
                    .disabled(store.phase == .unavailable)
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, 6)
        .frame(height: 44)
        .glassEffect(.regular, in: Capsule())
    }
}

/// Bottom card: where you are, road condition, mode, usage, change place.
private struct PlacesCard: View {
    @Environment(SkinStore.self) private var store
    @Environment(SkinRouter.self) private var router
    @Environment(SkinPreferences.self) private var preferences
    @Environment(\.skinTheme) private var theme

    var body: some View {
        let node = store.currentNode
        let grade = node?.grade ?? .untested
        VStack(alignment: .leading, spacing: 6) {
            if store.needsGate {
                NoProfileView()
            } else if store.isRunning {
                Text(skin: "You're going through").font(.system(.footnote, design: .rounded).weight(.semibold)).foregroundStyle(theme.secondaryText)
                HStack(alignment: .center, spacing: 10) {
                    Text(placeName(for: node?.tag))
                        .font(.system(size: 42, weight: .heavy, design: .rounded))
                        .foregroundStyle(theme.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Spacer()
                    HStack(spacing: 6) {
                        SignalBars(grade: grade, activeColor: grade.color)
                        Text(grade.word)
                    }
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(grade.color)
                    .padding(.horizontal, 12)
                    .frame(height: 32)
                    .background(grade.color.opacity(0.12), in: Capsule())
                }
                Text(SkinL("%@ · round trip %@", node.map { SkinRegion.stripFlag($0.tag) } ?? "—", SkinVocabulary.technical.latency(node?.delay ?? 0)))
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(theme.secondaryText)
                if store.clashModes.count > 1 {
                    Picker(SkinL("Routing"), selection: Binding(get: { store.clashMode }, set: { store.setClashMode($0) })) {
                        ForEach(store.clashModes, id: \.self) { Text(preferences.vocabulary.modeShort($0)).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .padding(.top, 10)
                }
                HStack {
                    Text(SkinL("Used %@ this session", SkinFormat.bytes(store.status.totalTraffic)))
                    Spacer()
                    Text(verbatim: "↓ \(SkinFormat.rate(store.status.downlink)) · ↑ \(SkinFormat.rate(store.status.uplink))")
                }
                .font(.system(.footnote, design: .rounded).monospacedDigit())
                .foregroundStyle(theme.secondaryText)
                .padding(.top, 6)
                Button {
                    router.showNodes()
                } label: {
                    Text(skin: "Change Place")
                        .font(.system(.headline, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .foregroundStyle(theme.background)
                        .background(theme.text, in: Capsule())
                }
                .buttonStyle(SkinPressStyle())
                .padding(.top, 8)
            } else {
                Text(skin: "You're not connected").font(.system(.footnote, design: .rounded).weight(.semibold)).foregroundStyle(theme.secondaryText)
                Text(store.phase.label)
                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                    .foregroundStyle(theme.text)
                Text(skin: "Turn it on and pick where you want to go.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(theme.secondaryText)
                Button {
                    store.startService()
                } label: {
                    Text(skin: "Turn On")
                        .font(.system(.headline, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .foregroundStyle(theme.onAccent)
                        .background(theme.accent, in: Capsule())
                }
                .buttonStyle(SkinPressStyle())
                .disabled(store.phase != .stopped)
                .padding(.top, 10)
            }
        }
        .padding(22)
        .background(theme.surface.opacity(0.92), in: RoundedRectangle(cornerRadius: 38, style: .continuous))
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 38, style: .continuous))
    }
}

// MARK: - “Where to?” picker

struct PlacesPicker: View {
    @Environment(SkinStore.self) private var store
    @Environment(SkinPreferences.self) private var preferences
    @Environment(\.skinTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    var initialGroup: String?
    var embedded = false
    @State private var groupTag: String?
    @State private var search = ""

    var body: some View {
        if embedded {
            content
        } else {
            NavigationStack {
                content
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(SkinL("Done")) { dismiss() }
                        }
                    }
            }
        }
    }

    private var content: some View {
        let selectable = store.groups.filter(\.selectable)
        let group = store.group(groupTag ?? initialGroup ?? "") ?? store.primaryGroup
        return List {
            if selectable.count > 1 {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(selectable) { item in
                            let selected = item.tag == group?.tag
                            Button {
                                groupTag = item.tag
                            } label: {
                                Text(item.tag)
                                    .font(.system(.subheadline, design: .rounded).weight(selected ? .bold : .regular))
                                    .padding(.horizontal, 16)
                                    .frame(height: 34)
                                    .foregroundStyle(selected ? theme.background : theme.text)
                                    .background(selected ? theme.text : theme.text.opacity(0.07), in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
            }
            if let group {
                let nested = group.items.filter { store.group($0.tag) != nil || $0.tag == "direct" }
                let places = group.items.filter { store.group($0.tag) == nil && $0.tag != "direct" }
                    .filter { search.isEmpty || $0.tag.localizedCaseInsensitiveContains(search) || placeName(for: $0.tag).localizedCaseInsensitiveContains(search) }
                if !nested.isEmpty, search.isEmpty {
                    Section {
                        ForEach(nested) { item in
                            PlacesAutoRow(group: group, item: item, isAutomatic: store.group(item.tag)?.isAutomatic == true)
                        }
                    }
                    .listRowBackground(theme.surface)
                }
                let buckets = Dictionary(grouping: places) { SkinRegion.infer(from: $0.tag)?.continent }
                ForEach(SkinRegion.Continent.allCases, id: \.self) { continent in
                    if let items = buckets[continent], !items.isEmpty {
                        Section(continent.displayName) {
                            ForEach(items) { PlacesRow(group: group, item: $0) }
                        }
                        .listRowBackground(theme.surface)
                    }
                }
                if let others = buckets[nil], !others.isEmpty {
                    Section(SkinL("Other")) {
                        ForEach(others) { PlacesRow(group: group, item: $0) }
                    }
                    .listRowBackground(theme.surface)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(theme.background)
        .searchable(text: $search, prompt: Text(skin: "Search places"))
        .navigationTitle(SkinL("Where to?"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    if let group { store.urlTest(group.tag) }
                } label: {
                    if let group, store.testingGroups.contains(group.tag) {
                        ProgressView()
                    } else {
                        Label(SkinL("Check roads"), systemImage: "bolt")
                    }
                }
            }
        }
    }
}

private struct PlacesRow: View {
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
                RegionBadge(tag: item.tag, selected: selected)
                VStack(alignment: .leading, spacing: 1) {
                    Text(SkinRegion.stripFlag(item.tag))
                        .font(.system(.body, design: .rounded).weight(selected ? .heavy : .medium))
                        .foregroundStyle(theme.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(item.type).font(.caption).foregroundStyle(theme.secondaryText)
                }
                Spacer()
                Text(item.grade.word)
                    .font(.system(.footnote, design: .rounded).weight(.semibold))
                    .foregroundStyle(item.grade.color)
                    .lineLimit(1)
                    .fixedSize()
                SignalBars(grade: item.grade)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!group.selectable)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct PlacesAutoRow: View {
    @Environment(SkinStore.self) private var store
    @Environment(\.skinTheme) private var theme
    let group: SkinOutboundGroup
    let item: SkinOutbound
    let isAutomatic: Bool

    var body: some View {
        let selected = item.tag == group.selected
        let nested = store.group(item.tag)
        Button {
            store.select(item.tag, in: group.tag)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isAutomatic ? "bolt.fill" : (item.tag == "direct" ? "arrow.right" : "square.stack.3d.up"))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(selected ? theme.onAccent : theme.accent)
                    .frame(width: 34, height: 34)
                    .background(selected ? theme.accent : theme.accent.opacity(0.12), in: Circle())
                VStack(alignment: .leading, spacing: 1) {
                    Text(isAutomatic ? SkinL("Pick the fastest for me") : item.tag)
                        .font(.system(.body, design: .rounded).weight(.bold))
                        .foregroundStyle(theme.text)
                    if let nested {
                        Text(SkinL("%@ · now %@", nested.tag, store.resolvedNode(in: nested).node.map { placeName(for: $0.tag) } ?? nested.selected))
                            .font(.caption)
                            .foregroundStyle(theme.secondaryText)
                    }
                }
                Spacer()
                if selected {
                    Image(systemName: "checkmark").font(.body.weight(.bold)).foregroundStyle(theme.accent)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!group.selectable)
    }
}

// MARK: - iPad / Mac

private struct PlacesRegular: View {
    @Environment(SkinStore.self) private var store
    @Environment(SkinRouter.self) private var router
    @Environment(SkinPreferences.self) private var preferences
    @Environment(\.skinTheme) private var theme

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()
            GeometryReader { proxy in
                // Wide enough to show neighbours, zoomed enough for readable dots.
                let span = min(220, max(120, Double(proxy.size.width) / 6))
                PlacesMap(span: span)
                    .padding(.leading, 330)
                    .padding(.bottom, 110)
            }
            .ignoresSafeArea()
            .opacity(store.isRunning ? 1 : 0.55)
            HStack(alignment: .top, spacing: 0) {
                NavigationStack {
                    PlacesPicker(embedded: true)
                }
                .frame(width: 320)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .padding(10)
                VStack(alignment: .trailing) {
                    HStack(spacing: 10) {
                        Button {
                            router.sheet = .more
                        } label: {
                            Image(systemName: "line.3.horizontal")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(theme.text)
                                .frame(width: 44, height: 44)
                                .glassEffect(.regular.interactive(), in: Circle())
                        }
                        .buttonStyle(.plain)
                        if store.isRunning, store.clashModes.count > 1 {
                            Picker(SkinL("Routing"), selection: Binding(get: { store.clashMode }, set: { store.setClashMode($0) })) {
                                ForEach(store.clashModes, id: \.self) { Text(preferences.vocabulary.modeShort($0)).tag($0) }
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                            .fixedSize()
                            .padding(6)
                            .glassEffect(.regular, in: Capsule())
                        }
                        PlacesPowerSwitch()
                    }
                    Spacer()
                    PlacesStatusBar()
                }
                .padding(14)
            }
        }
    }
}

private struct PlacesStatusBar: View {
    @Environment(SkinStore.self) private var store
    @Environment(SkinRouter.self) private var router
    @Environment(\.skinTheme) private var theme

    var body: some View {
        ViewThatFits(in: .horizontal) {
            bar(showsStats: true)
            bar(showsStats: false)
        }
        .frame(maxWidth: 1000)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func bar(showsStats: Bool) -> some View {
        let node = store.currentNode
        let grade = node?.grade ?? .untested
        return HStack(spacing: 28) {
            VStack(alignment: .leading, spacing: 2) {
                Text(store.isRunning ? SkinL("You're going through") : store.phase.label).font(.caption.weight(.semibold)).foregroundStyle(theme.secondaryText)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(store.isRunning ? placeName(for: node?.tag) : "—").font(.system(size: 26, weight: .heavy, design: .rounded)).foregroundStyle(theme.text)
                    if store.isRunning {
                        Text(verbatim: "\(grade.word) · \(SkinVocabulary.technical.latency(node?.delay ?? 0))").font(.subheadline.weight(.bold)).foregroundStyle(grade.color)
                    }
                }
            }
            if store.isRunning, showsStats {
                Divider().frame(height: 40)
                stat(SkinL("Now"), "↓ \(SkinFormat.rate(store.status.downlink))  ↑ \(SkinFormat.rate(store.status.uplink))")
                stat(SkinL("This session"), SkinFormat.bytes(store.status.totalTraffic))
                stat(SkinL("Open"), SkinL("%lld connections", store.status.totalConnections))
            }
            Spacer(minLength: 0)
            Button {
                router.sheet = .connections
            } label: {
                Text(skin: "See Activity")
                    .font(.subheadline.weight(.bold))
                    .padding(.horizontal, 16)
                    .frame(height: 38)
                    .foregroundStyle(theme.text)
                    .background(theme.surface, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .frame(height: 84)
        .fixedSize(horizontal: true, vertical: false)
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(theme.secondaryText)
            Text(value).font(.system(.headline, design: .rounded).monospacedDigit()).foregroundStyle(theme.text)
        }
    }
}
