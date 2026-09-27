import SkywaveShared
import SwiftUI

/// Three signal bars for a latency grade.
struct SignalBars: View {
    var grade: LatencyGrade
    var activeColor: Color?
    var inactiveColor: Color = .secondary.opacity(0.25)

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0 ..< 3, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(index < grade.bars ? (activeColor ?? grade.color) : inactiveColor)
                    .frame(width: 3, height: CGFloat(4 + index * 4))
            }
        }
        .frame(height: 12, alignment: .bottom)
        .accessibilityHidden(true)
    }
}

/// `52 ms` / `Very fast`, tinted by grade.
struct LatencyText: View {
    @Environment(SkinPreferences.self) private var preferences
    var delay: UInt16
    var font: Font = .subheadline
    var tinted = true

    var body: some View {
        let grade = LatencyGrade(delay: delay)
        Text(preferences.vocabulary.latency(delay))
            .font(font)
            .monospacedDigit()
            .foregroundStyle(tinted ? AnyShapeStyle(grade.color) : AnyShapeStyle(.secondary))
            .accessibilityLabel(Text(LatencyGrade(delay: delay).word))
    }
}

/// Live elapsed time since the service started; keeps ticking without a store update.
struct ElapsedText: View {
    var since: Date?

    var body: some View {
        if let since {
            Text(since, style: .timer)
                .monospacedDigit()
        } else {
            Text(verbatim: "0:00")
                .monospacedDigit()
        }
    }
}

/// Human readable service state.
extension ServicePhase {
    var label: String {
        switch self {
        case .unavailable: SkinL("Not set up")
        case .stopped: SkinL("Stopped")
        case .starting: SkinL("Starting…")
        case .running: SkinL("Connected")
        case .reasserting: SkinL("Reconnecting…")
        case .stopping: SkinL("Stopping…")
        }
    }
}

/// Small colored dot for status.
struct StatusDot: View {
    var phase: ServicePhase
    var size: CGFloat = 8

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .shadow(color: phase == .running ? color.opacity(0.6) : .clear, radius: 3)
            .accessibilityHidden(true)
    }

    private var color: Color {
        switch phase {
        case .running: SkinPalette.good
        case .starting, .reasserting, .stopping: SkinPalette.medium
        case .stopped, .unavailable: .secondary
        }
    }
}

/// Two-letter region badge (never an emoji) used by Places and the node pickers.
struct RegionBadge: View {
    var tag: String
    var selected = false
    var size: CGFloat = 34
    @Environment(\.skinTheme) private var theme

    var body: some View {
        let code = SkinRegion.infer(from: tag)?.code ?? String(SkinRegion.stripFlag(tag).prefix(1)).uppercased()
        Text(verbatim: code)
            .font(.system(size: size * 0.32, weight: .heavy, design: .rounded))
            .tracking(0.4)
            .foregroundStyle(selected ? theme.onAccent : theme.secondaryText)
            .frame(width: size, height: size)
            .background(selected ? theme.accent : theme.text.opacity(0.07), in: Circle())
            .accessibilityHidden(true)
    }
}
