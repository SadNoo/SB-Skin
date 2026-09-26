import SBSkinShared
import SwiftUI

/// Hardware parts shared by the phone and desktop layouts of the Radio skin.
enum RadioStyle {
    static let lcd = Color(hex: 0x1D2320)
    static let amber = Color(hex: 0xFFA640)
    static let orange = Color(hex: 0xFF5A1F)
    static let keyShadow = Color(light: Color(hex: 0xB9B4A9), dark: Color(hex: 0x14130F))
    static let grille = Color(light: Color(hex: 0xB9B4A9), dark: Color(hex: 0x4A4741))
}

/// The band (group) the radio is tuned to and the stations (members) on it.
@MainActor
struct RadioTuning {
    let store: SkinStore
    let preferences: SkinPreferences

    var bands: [SkinOutboundGroup] { store.groups.filter(\.selectable) }

    var band: SkinOutboundGroup? {
        bands.first { $0.tag == preferences.radioBand } ?? store.primaryGroup.flatMap { primary in bands.first { $0.tag == primary.tag } } ?? bands.first
    }

    func nextBand() {
        guard let band, let index = bands.firstIndex(of: band), !bands.isEmpty else { return }
        preferences.radioBand = bands[(index + 1) % bands.count].tag
    }
}

/// Speaker grille of staggered dots.
struct RadioGrille: View {
    var rows = 6

    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 11
            var path = Path()
            for row in 0 ..< rows {
                var x: CGFloat = row.isMultiple(of: 2) ? 5 : 10.5
                let y = 5 + CGFloat(row) * 10
                while x < size.width - 4 {
                    path.addEllipse(in: CGRect(x: x - 2.5, y: y - 2.5, width: 5, height: 5))
                    x += spacing
                }
            }
            context.fill(path, with: .color(RadioStyle.grille))
        }
        .frame(height: CGFloat(rows) * 10 + 2)
        .accessibilityHidden(true)
    }
}

/// Amber LCD: band, station, delay, uptime, VU meters.
struct RadioLCD: View {
    @Environment(SkinStore.self) private var store
    let bandName: String
    let channel: String
    let station: String
    let detail: String
    var large = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 14) {
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: "\(bandName.uppercased()) · \(channel)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .tracking(2)
                    .opacity(0.6)
                    .lineLimit(1)
                Text(station)
                    .font(.system(size: large ? 40 : 34, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .shadow(color: RadioStyle.amber.opacity(0.5), radius: 8)
                    .padding(.top, 6)
                Spacer(minLength: 8)
                Text(detail)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .tracking(1)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            HStack(alignment: .bottom, spacing: 6) {
                VUMeter(level: level(store.status.downlink), label: "↓")
                VUMeter(level: level(store.status.uplink), label: "↑")
            }
        }
        .foregroundStyle(RadioStyle.amber)
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(height: large ? 170 : 150)
        .background(RadioStyle.lcd, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.black.opacity(0.4), lineWidth: 2))
        .shadow(color: .white.opacity(0.6), radius: 0, y: 1)
        .accessibilityElement(children: .combine)
    }

    /// Logarithmic 0…12 so both 20 KB/s and 20 MB/s move the needle.
    private func level(_ rate: Int64) -> Int {
        guard rate > 1024 else { return 0 }
        let value = log10(Double(rate) / 1024) / log10(64 * 1024) * 12
        return min(12, max(1, Int(value.rounded())))
    }
}

struct VUMeter: View {
    let level: Int
    let label: String

    var body: some View {
        VStack(spacing: 3) {
            ForEach((0 ..< 12).reversed(), id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(index < level ? (index >= 10 ? RadioStyle.orange : RadioStyle.amber) : RadioStyle.amber.opacity(0.12))
                    .frame(width: 14, height: 6)
            }
            Text(verbatim: label).font(.system(size: 9, design: .monospaced)).opacity(0.6)
        }
        .animation(.easeOut(duration: 0.2), value: level)
    }
}

/// Tuning scale with a needle; the selected station sits under the needle.
struct RadioScale: View {
    let stations: [SkinOutbound]
    let tunedIndex: Int
    var onTap: (Int) -> Void

    private let spacing: CGFloat = 46

    var body: some View {
        GeometryReader { proxy in
            let offset = proxy.size.width / 2 - CGFloat(tunedIndex) * spacing - spacing / 2
            ZStack(alignment: .topLeading) {
                Canvas { context, size in
                    var ticks = Path()
                    let count = Int(size.width / 5.5) + 1
                    for index in 0 ... count {
                        let x = CGFloat(index) * 5.5
                        let height: CGFloat = index % 8 == 0 ? 28 : (index % 4 == 0 ? 18 : 10)
                        ticks.move(to: CGPoint(x: x, y: 0))
                        ticks.addLine(to: CGPoint(x: x, y: height))
                    }
                    context.stroke(ticks, with: .color(Color(hex: 0x1A1A1A).opacity(0.85)), lineWidth: 1.1)
                }
                HStack(spacing: 0) {
                    ForEach(Array(stations.enumerated()), id: \.element.id) { index, station in
                        Button {
                            onTap(index)
                        } label: {
                            VStack(spacing: 2) {
                                Text(RadioScale.code(for: station.tag))
                                    .font(.system(size: 11, weight: .heavy))
                                    .foregroundStyle(index == tunedIndex ? RadioStyle.orange : Color(hex: 0x1A1A1A))
                                Text(station.delay > 0 && station.delay != .max ? "\(station.delay)" : "--")
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundStyle(Color(hex: 0x6F6A60))
                            }
                            .frame(width: spacing, height: 40)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(station.tag))
                    }
                }
                .offset(x: offset, y: 30)
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: tunedIndex)
                Rectangle()
                    .fill(RadioStyle.orange)
                    .frame(width: 3)
                    .shadow(color: RadioStyle.orange.opacity(0.7), radius: 4)
                    .offset(x: proxy.size.width / 2 - 1.5)
            }
        }
        .frame(height: 72)
        .background(Color(hex: 0xF4F2ED), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.black.opacity(0.12)))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    /// Short station code: region (HK), else first letters of the tag.
    static func code(for tag: String) -> String {
        if let region = SkinRegion.infer(from: tag) {
            let digits = tag.filter(\.isNumber).suffix(2)
            return region.code + (digits.isEmpty ? "" : String(Int(digits) ?? 0))
        }
        let clean = SkinRegion.stripFlag(tag)
        return String(clean.prefix(3)).uppercased()
    }
}

/// Rotary tuning knob. Every 30° of rotation moves one station; the choice commits on release.
struct RadioKnob: View {
    var diameter: CGFloat = 180
    var stationCount: Int
    @Binding var tunedIndex: Int
    var onCommit: (Int) -> Void

    @State private var rotation: Double = 0
    @State private var lastAngle: Double?
    @State private var accumulated: Double = 0
    private let step = Double.pi / 6

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [Color(hex: 0xFBFAF7), Color(hex: 0xD3CFC6), Color(hex: 0xBDB8AD)], center: UnitPoint(x: 0.38, y: 0.32), startRadius: 4, endRadius: diameter * 0.62))
                .shadow(color: .black.opacity(0.25), radius: 14, y: 12)
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                var grip = Path()
                for index in 0 ..< 60 {
                    let angle = Double(index) / 60 * 2 * .pi
                    let inner = size.width * 0.33
                    let outer = size.width * 0.38
                    grip.move(to: CGPoint(x: center.x + cos(angle) * inner, y: center.y + sin(angle) * inner))
                    grip.addLine(to: CGPoint(x: center.x + cos(angle) * outer, y: center.y + sin(angle) * outer))
                }
                context.stroke(grip, with: .color(.black.opacity(0.08)), lineWidth: 1.5)
            }
            Capsule()
                .fill(RadioStyle.orange)
                .frame(width: 6, height: diameter * 0.15)
                .offset(y: -diameter * 0.36)
        }
        .rotationEffect(.radians(rotation))
        .frame(width: diameter, height: diameter)
        .contentShape(Circle())
        .gesture(dragGesture)
        .sensoryFeedback(.selection, trigger: tunedIndex)
        .accessibilityElement()
        .accessibilityLabel(Text(skin: "Tuning knob"))
        .accessibilityHint(Text(skin: "Swipe up or down to change station."))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: move(1); onCommit(tunedIndex)
            case .decrement: move(-1); onCommit(tunedIndex)
            @unknown default: break
            }
        }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let center = CGPoint(x: diameter / 2, y: diameter / 2)
                let angle = atan2(value.location.y - center.y, value.location.x - center.x)
                guard let previous = lastAngle else {
                    lastAngle = angle
                    return
                }
                var delta = angle - previous
                if delta > .pi { delta -= 2 * .pi }
                if delta < -.pi { delta += 2 * .pi }
                lastAngle = angle
                rotation += delta
                accumulated += delta
                while accumulated > step { accumulated -= step; move(1) }
                while accumulated < -step { accumulated += step; move(-1) }
            }
            .onEnded { _ in
                lastAngle = nil
                accumulated = 0
                onCommit(tunedIndex)
            }
    }

    private func move(_ delta: Int) {
        guard stationCount > 0 else { return }
        tunedIndex = min(max(tunedIndex + delta, 0), stationCount - 1)
    }
}

/// Piano-style key; sinks when on.
struct RadioKey: View {
    @Environment(\.skinTheme) private var theme
    let title: String
    let isOn: Bool
    var dark = false
    var height: CGFloat = 58
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Circle()
                    .fill(isOn ? RadioStyle.orange : (dark ? Color(hex: 0x555555) : Color(hex: 0xC9C4BA)))
                    .frame(width: 8, height: 8)
                    .shadow(color: isOn ? RadioStyle.orange.opacity(0.8) : .clear, radius: 4)
                Text(title).font(.system(size: 13, weight: .heavy)).lineLimit(1).minimumScaleFactor(0.7)
            }
            .foregroundStyle(dark ? Color(hex: 0xE6E3DC) : Color(hex: 0x1A1A1A))
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(dark ? Color(hex: 0x1A1A1A) : (isOn ? Color(hex: 0xD6D2C9) : Color(hex: 0xF4F2ED)))
                    .shadow(color: isOn ? .clear : (dark ? .black : RadioStyle.keyShadow), radius: 0, y: isOn ? 0 : 4)
            }
            .offset(y: isOn ? 3 : 0)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isOn)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// Orange power lever.
struct RadioPowerLever: View {
    @Environment(SkinStore.self) private var store
    var vertical = true

    var body: some View {
        let on = store.phase.isActive
        Button {
            store.toggleService()
        } label: {
            ZStack(alignment: vertical ? (on ? .top : .bottom) : (on ? .trailing : .leading)) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(hex: 0xD6D2C9))
                    .shadow(color: .black.opacity(0.2), radius: 3, y: 2)
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(on ? RadioStyle.orange : Color(hex: 0x8A857B))
                    .frame(width: vertical ? nil : 50, height: vertical ? 54 : nil)
                    .padding(6)
                    .shadow(color: .black.opacity(0.25), radius: 4, y: 3)
            }
            .frame(width: vertical ? 62 : 110, height: vertical ? 110 : 62)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: on)
        }
        .buttonStyle(.plain)
        .disabled(store.phase == .unavailable || store.phase.isTransitioning)
        .sensoryFeedback(.impact(weight: .heavy), trigger: on)
        .accessibilityLabel(Text(skin: "Power"))
        .accessibilityValue(Text(on ? SkinL("On") : SkinL("Off")))
    }
}
